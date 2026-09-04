---
layout: post
title: "GTIDs, Kafka Consumer Offsets, and What a Recovery Checkpoint Really Means"
date: 2026-09-03
categories:
  - Software Engineering
tags:
  - MySQL
  - Kafka
  - Amazon MSK
  - Distributed Systems
  - Disaster Recovery
  - Event Streaming
description: "A recent MySQL replication change made me reconsider a question from Kafka disaster recovery: does a checkpoint identify what was processed, or merely where processing should resume?"
comments: true
---

A recent MySQL change caught my attention because it intersects with a problem I have been thinking about while working through disaster recovery for an Event Streaming Platform built on Kafka.

The change is quite recent.

MySQL 26.7.0 was released on July 28, 2026. Among its replication changes, MySQL introduced the Change Stream Applier, or CSA, a new implementation of the replica SQL applier for multithreaded replication. CSA is currently opt in, but some of its requirements are interesting: it does not support file position replication channels, requires `GTID_MODE=ON`, and requires `GTID_ONLY=1`.[^mysql-csa]

What interested me was not GTID itself, but what the requirement implies: MySQL’s newer replication machinery is making transaction identity a prerequisite while leaving file position replication behind. That made me ask what the equivalent recovery state actually is in Kafka.

## File Position Versus Transaction Identity

Traditional MySQL replication can describe progress using a binary log file and byte position:

```text
mysql-bin.004217:18372944
```

That is a location.

It essentially answers the following question:

> What location or position should I continue from?

A Global Transaction Identifier answers a different question.

MySQL assigns a GTID to a transaction when that transaction is committed on its originating server and written to the binary log. When the transaction is replicated, it retains the same GTID on the replica.[^mysql-gtid]

Conceptually, a GTID looks like:

```text
server-uuid:transaction-number
```

So the transaction can appear in different binary log files and at different positions as it moves through the topology, while its logical identity remains unchanged.

With GTID-based replication, MySQL therefore does not need to rely on binary log filenames and positions when establishing a new replica or failing over to another source. MySQL can reason about which transactions have already been executed and which are still missing.[^mysql-gtid-failover]

The recovery question changes from:

```text
Where was I?
```

to:

```text
Which transactions have I already applied?
```

That distinction immediately reminded me of Kafka.

## Kafka Offsets Are Positions Too

Kafka assigns each record a monotonically increasing offset within a topic partition.

For example:

```text
orders
partition 7
offset 928471
```

The offset identifies a position in that partition's log.

It does not globally identify the business event.

There is an important difference from a raw MySQL binary log position, however.

Within a Kafka cluster, a partition is replicated across brokers. If the leader broker for a partition fails and another replica becomes leader, consumers still operate in terms of the same topic, partition, and offset space.[^kafka-replication]

The broker that physically serves the partition can change without changing the consumer's logical position in the partition.

So Kafka already separates:

```text
physical broker placement
```

from:

```text
topic + partition + offset
```

That is why ordinary broker failover is relatively transparent to consumers.

But Kafka disaster recovery across clusters introduces another problem.

## Consumer Offsets Belong to Consumer Groups

Kafka does not maintain a single consumer position for a topic.

A committed consumer position is associated with a consumer group and a topic partition:

```text
consumer-group
    +
topic
    +
partition
    →
committed offset
```

Kafka stores committed consumer group offsets in the internal compacted topic `__consumer_offsets`.[^kafka-offset-storage]

For example:

```text
group: payment-processor
topic: payments
partition: 3
committed offset: 10001
```

Strictly speaking, the committed offset normally represents the **next record to consume**. If the consumer successfully processed record `10000`, it would normally commit `10001`.[^kafka-commit-semantics]

Another consumer group reading the same partition can have a completely different committed position.

## A DR Kafka Cluster Is Another Log

Now suppose we have two Amazon MSK clusters:

```text
Primary Region
    ↓
MSK Replicator
    ↓
DR Region
```

The DR cluster receives copies of records from the primary cluster.

But MSK Replicator does not copy the underlying Kafka partition log byte for byte. It replicates records into the target cluster and maintains mappings between source and target offsets.[^msk-offset-sync]

As a result, the same logical record can have different Kafka offsets in the two clusters.

For example:

```text
Primary cluster

payments
partition 3
offset 10000
```

might correspond to:

```text
DR cluster

payments
partition 3
offset 9873
```

That means 

```text
source offset != target offset
```

in general.

Therefore, simply copying a consumer group's numerical offset from one cluster into another would be unsafe.

Offset `10001` in the DR cluster is not guaranteed to represent the same point in the event history as offset `10001` in the primary cluster.

This is where Amazon MSK Replicator does something more sophisticated.

## MSK Replicator Can Migrate Consumer Progress

Amazon MSK Replicator supports consumer group offset synchronization. This capability is enabled by default unless explicitly disabled.[^msk-offset-default]

The process has three conceptual stages.

First, while records are replicated, MSK Replicator periodically records mappings between source offsets and corresponding target offsets.

Conceptually:

```text
Source                    Target

1000    ───────────────→   872
1100    ───────────────→   971
1200    ───────────────→  1074
```

Second, Replicator reads committed offsets for consumer groups in the source cluster.

Third, it translates those source positions into corresponding target positions and commits the translated offsets into the target cluster's `__consumer_offsets` topic.[^msk-offset-sync]

Suppose the primary cluster contains:

```text
consumer group: payment-processor
topic: payments
partition: 3
committed offset: 10001
```

Replicator might determine that the corresponding recovery position in the DR cluster is:

```text
consumer group: payment-processor
topic: payments
partition: 3
committed offset: 9874
```

When `payment-processor` is subsequently started against the DR cluster using the same `group.id`, it can resume near the corresponding point in the replicated stream rather than starting from the beginning or end of the topic.[^msk-offset-sync]

That is a significant DR capability.

Amazon MSK is not merely replicating the events. The recovery system can also migrate the consumer's progress through those events.

## But the Translation Is Deliberately Approximate

Amazon documents that MSK Replicator's offset translation is approximate rather than exact.

Replicator records offset mappings periodically rather than maintaining an exact source-to-target mapping for every individual record. The translated target offset can therefore be slightly behind the precise equivalent position.[^msk-offset-sync]

This is intentional.

The safer failure mode is:

```text
replay some records
```

rather than:

```text
skip records
```

Suppose the source consumer had reached:

```text
10000
```

but the closest safe translated checkpoint corresponds to slightly earlier in the target:

```text
9997
```

After failover, the consumer might see the logical equivalents of records `9997`, `9998`, `9999`, and `10000` again.

AWS describes this behavior in terms of *at-least-once delivery* and recommends that applications tolerate duplicate processing.[^msk-offset-sync][^msk-migration]

This is where the comparison with MySQL GTIDs becomes more interesting.

## A Translated Offset Is Still Not an Event Identity

Consider a payment event:

```json
{
  "eventId": "01KABC...",
  "eventType": "PaymentCompleted",
  "paymentId": "P12345"
}
```

It might exist here in the primary cluster:

```text
payments-3 @ 10000
```

and here in the DR cluster:

```text
payments-3 @ 9873
```

MSK Replicator can establish that those positions correspond close enough to migrate the `payment-processor` consumer group's recovery position.

But neither Kafka offset intrinsically identifies the payment event. The event contract does that through `eventId` or another stable idempotency key.

The distinction is:

```text
Event identity
    ↓
What logical event is this?

Kafka log position
    ↓
Where is this record in this partition?

Consumer group checkpoint
    ↓
Where should this group resume?

Cross-cluster offset translation
    ↓
Where does that checkpoint approximately correspond
in another Kafka cluster?
```

These concepts often appear to be the same during normal operation because they move together.

Disaster recovery exposes the differences.

## GTID and Kafka Offset Translation Solve Different Problems

This is where I would avoid making a direct equivalence between MySQL GTIDs and Kafka consumer offsets.

A MySQL GTID identifies the transaction itself.

The identifier survives replication. MySQL replicas preserve the GTID assigned at the originating server, and MySQL can use the set of transactions already executed to determine what still needs to be replicated.[^mysql-gtid][^mysql-gtid-failover]

Kafka uses positions for log navigation and consumer recovery:

```text
topic + partition + offset
    ↓
record location

group + topic + partition + committed offset
    ↓
consumer recovery position

MSK offset translation
    ↓
corresponding recovery position
in another cluster
```

Those are capable mechanisms, but they do not identify the business event or prove that an external side effect has already occurred.

Suppose `payment-processor` receives:

```text
PaymentCompleted
eventId = 01KABC
```

The consumer updates a downstream database.

Then, before every relevant checkpoint has propagated into the DR environment, the primary region fails.

The event itself has already reached the DR cluster.

The synchronized consumer position is slightly behind because offset synchronization is asynchronous and approximate.[^msk-offset-sync]

After failover, `payment-processor` encounters `01KABC` again.

Kafka has not necessarily failed as Replicator has actually worked and consumer group offset synchronization has worked as well. The recovery mechanism intentionally selected a position that avoided losing records.

The remaining question is now an application question:

```text
Have I already applied event 01KABC?
```

A Kafka offset cannot answer that question across arbitrary external side effects.

A stable event identity or idempotency key can.

This is why at-least-once delivery and idempotent processing are so closely related in event-driven systems.

## There Is More Than One Kind of DR State

Thinking about this also changes how I interpret statements such as:

```text
RPO = 0
```

for an Event Streaming Platform. `RPO=0` essentially means there should be no data loss or in technical terms:

> An RPO of zero means that no state the platform considers successfully committed before the failure may be lost.

This also exposes an important limitation of asynchronous Kafka replication. Amazon MSK Replicator copies records asynchronously. A producer can therefore receive an acknowledgement from the primary cluster before that record has reached the DR cluster. If the primary Region becomes unrecoverable during that interval, the replicated system cannot strictly guarantee an event-data RPO of zero.[^msk-replicator] `MessageLag = 0` tells us that Replicator has caught up at that moment; it does not change the asynchronous nature of the replication path.[^msk-monitoring]

Three different recovery concerns now appear, but only the first is directly the Kafka event-data RPO:

### Event Log State

Have all events acknowledged in the primary Kafka cluster been replicated into the DR cluster?

This is the traditional data replication question.

### Consumer Processing State

How closely do the translated consumer group offsets in DR represent the committed processing positions in the primary cluster?

Amazon MSK exposes separate metrics for replication lag and consumer group offset synchronization because these are distinct pieces of replication state.[^msk-monitoring]

### Business Effect State

If an event is replayed after failover, can the consuming application determine whether the corresponding business operation has already been applied?

This state may live outside Kafka entirely.

A system can therefore experience:

```text
zero lost Kafka records
```

while still experiencing:

```text
replayed records
```

after failover.

Replay is not data loss. Therefore consumer-offset lag does not necessarily violate the Kafka event-data RPO.

In fact, the conservative offset translation performed by MSK Replicator intentionally prefers replay over skipping records.[^msk-offset-sync]

Whether that replay is harmless depends on the consumer.

## Broker Failover and Cluster Failover Are Different Problems

Kafka's normal high availability can make this distinction easy to miss.

Within one cluster:

```text
Broker A fails
      ↓
Broker B becomes partition leader
      ↓
same topic
same partition
same logical log
same offset space
```

The consumer group continues operating against the same Kafka cluster abstraction.

Cross-cluster disaster recovery is different:

```text
Primary partition
      ↓
replication
      ↓
DR partition
      ↓
different Kafka log
      ↓
offset mapping
      ↓
consumer group offset translation
```

Kafka has moved from replica failover to log translation.

That is a fundamentally different recovery problem.

Apache Kafka's MirrorMaker 2 addresses the same general problem through offset sync and checkpoint mechanisms. KIP-545 added automated synchronization of translated consumer group offsets into a target cluster so that selected consumer groups can resume processing there.[^kip545]

Amazon MSK Replicator provides a managed implementation of this broader DR capability for supported MSK configurations.[^msk-replicator]

## What the MySQL Change Made Me Think About

The interesting part of MySQL 26.7 is that MySQL's new Change Stream Applier is being introduced with GTID-based replication as a requirement while file-position replication channels are explicitly unsupported.[^mysql-csa]

This reinforces a principle that applies well beyond databases:

> Recovery becomes easier when the thing being recovered has an identity independent of the location where it happened to be stored.

Kafka illustrates both sides of this idea.

Inside a Kafka cluster, the abstraction is already stronger than physical broker location. Consumers reason about topic partitions and offsets rather than disk locations on particular brokers.

Across Kafka clusters, that abstraction reaches a boundary. The destination has its own log and therefore its own offsets.

Systems such as MSK Replicator bridge that boundary by translating consumer progress from one offset space into another.

That solves an important recovery problem.

But it does not turn the Kafka offset into the identity of the event. 

This is not an argument that Kafka should replace offsets with event identifiers. They solve different problems. Position is what makes ordered log consumption efficient. Identity is what lets a system recognize the same logical operation when location and execution history diverge. Robust recovery often needs both.

Basically,
```
Position
    → where should I continue?

Identity
    → have I seen this logical thing before
```

## The Question I Now Ask

When I look at a recovery mechanism now, I want to ask:

> Does this checkpoint identify the state I processed, or merely where I should resume looking for it?

Sometimes a position is exactly what we need.

Kafka consumer group offsets are an excellent example. MSK Replicator can even translate those positions across clusters and preserve consumer recovery state.

But position and identity are still different concepts.

For Kafka DR, I now think about recovery in layers:

```text
Did the event survive?

Did the consumer's progress survive?

Can that progress be translated into the DR log?

If some events are replayed,
can the application recognize them?

If an event is recognized,
can its side effects safely be repeated or suppressed?
```

The first questions belong largely to the streaming platform.

The final questions increasingly belong to the consumer application.

----
[^mysql-csa]: Oracle, "Changes in MySQL 26.7.0 (2026-07-28)," *MySQL 26.7 Release Notes*. The release introduces the Change Stream Applier and lists file-position replication channels, GTID modes other than `ON`, and `GTID_ONLY=0` among unsupported configurations. <https://dev.mysql.com/doc/relnotes/mysql/26.7/en/news-26-7-0.html>

[^mysql-gtid]: Oracle, "GTID Format and Storage," *MySQL Reference Manual*. MySQL defines a GTID as a unique identifier associated with a transaction committed on its originating server and states that replicated transactions retain the same GTID. <https://dev.mysql.com/doc/refman/9.1/en/replication-gtids-concepts.html>

[^mysql-gtid-failover]: Oracle, "Replication with Global Transaction Identifiers," *MySQL Reference Manual*. MySQL documents that GTID-based replication removes the need to refer to binary log files and positions when starting a replica or failing over to a new source. <https://dev.mysql.com/doc/refman/9.4/en/replication-gtids.html>

[^kafka-replication]: Apache Kafka, "Replication," *Kafka Design Documentation*. Kafka partitions are replicated across brokers, with one replica acting as leader and other replicas able to take over leadership. <https://kafka.apache.org/documentation/#replication>

[^kafka-offset-storage]: Apache Kafka, "Consumer Offset Tracking," *Kafka Implementation Documentation*. Kafka documents that consumer offsets are maintained for consumer groups and that offset commits are stored in the compacted `__consumer_offsets` topic. <https://kafka.apache.org/42/implementation/distribution/>

[^kafka-commit-semantics]: Apache Kafka, `KafkaConsumer` API documentation. The consumer API specifies that a committed offset should identify the next record to be processed rather than the offset of the record just processed. <https://kafka.apache.org/42/javadoc/org/apache/kafka/clients/consumer/KafkaConsumer.html>

[^msk-offset-sync]: Amazon Web Services, "Consumer group offset synchronization," *Amazon MSK Developer Guide*. AWS documents source-to-target offset mapping, translation of source consumer group offsets, committing translated offsets into the target cluster, and the approximate nature of the translation. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-bidirectional-offset-sync.html>

[^msk-offset-default]: Amazon Web Services, "Create a replicator using the AWS Management Console," *Amazon MSK Developer Guide*. AWS documents consumer group offset synchronization as part of MSK Replicator configuration. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-create-console.html>

[^msk-migration]: Amazon Web Services, "Migrate between Amazon MSK clusters," *Amazon MSK Developer Guide*. AWS notes the at-least-once characteristics of replication and recommends consumers be able to handle duplicate messages. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-migrate-cluster.html>

[^msk-monitoring]: Amazon Web Services, "Monitor an MSK Replicator," *Amazon MSK Developer Guide*. AWS exposes metrics for message replication and consumer group offset synchronization, allowing replication state and consumer checkpoint synchronization to be monitored separately. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-monitor.html>

[^kip545]: Apache Kafka, "KIP-545: Support automated consumer offset sync across clusters in MM 2.0." The KIP describes translating and synchronizing consumer group offsets between Kafka clusters. <https://cwiki.apache.org/confluence/display/KAFKA/KIP-545%3A+support+automated+consumer+offset+sync+across+clusters+in+MM+2.0>

[^msk-replicator]: Amazon Web Services, "What is Amazon MSK Replicator?" *Amazon MSK Developer Guide*. AWS describes MSK Replicator as a managed capability for asynchronous replication between Amazon MSK clusters, including replication of Kafka data and consumer group offsets. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator.html>

[^msk-supported]: Amazon Web Services, "Supported configurations and requirements for MSK Replicator," *Amazon MSK Developer Guide*. AWS documents the supported source and target account and Region configurations for MSK Replicator. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-supported-configs.html>

[^msk-cross-account]: Amazon Web Services, "Cross-account migration between Amazon MSK clusters," *Amazon MSK Developer Guide*. AWS documents MirrorMaker 2 as the approach for cross-account Amazon MSK cluster replication where MSK Replicator cannot be used. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-cross-account.html>