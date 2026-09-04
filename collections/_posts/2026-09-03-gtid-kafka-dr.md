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
  - AI-assisted
description: "A recent MySQL replication change made me reconsider a question from Kafka disaster recovery: does a checkpoint identify what was processed, or merely where processing should resume?"
comments: true
---
A recent MySQL change caught my attention because it intersects with a problem I have been thinking about while working through disaster recovery for an Event Streaming Platform built on Kafka.

MySQL 26.7.0 was released on July 28, 2026. Among its replication changes, MySQL introduced the Change Stream Applier, or CSA, a new implementation of the replica SQL applier for multithreaded replication. CSA is currently opt in, but some of its requirements are interesting: it does not support file position replication channels, requires `GTID_MODE=ON`, and requires `GTID_ONLY=1`.[^mysql-csa]

What interested me was not GTID itself, but what the requirement implies: MySQL's newer replication machinery is making transaction identity a prerequisite while leaving file position replication behind.

That made me ask what the equivalent recovery state actually is in Kafka.

## File Position Versus Transaction Identity

Traditional MySQL replication can describe progress using a binary log file and byte position:

```text
mysql-bin.004217:18372944
```

That answers:

> What location should I continue from?

A Global Transaction Identifier answers a different question.

MySQL assigns a GTID to a transaction when that transaction is committed on its originating server. When the transaction is replicated, it retains the same GTID on the replica.[^mysql-gtid]

Conceptually:

```text
server-uuid:transaction-number
```

The transaction can appear in different binary log files and at different positions as it moves through the topology, while its identity remains unchanged.

With GTID-based replication, MySQL can reason about which transactions have already been executed and which are still missing without depending on binary log filenames and positions.[^mysql-gtid-failover]

The recovery question changes from:

```text
Where was I?
```

to:

```text
Which transactions have I already applied?
```

That distinction immediately reminded me of Kafka.

## Kafka Uses Positions Differently

Kafka assigns each record a monotonically increasing offset within a topic partition:

```text
orders
partition 7
offset 928471
```

The offset identifies a position in that partition's log. It does not globally identify the business event.

Within a Kafka cluster, however, the offset is already independent of physical broker placement. A partition is replicated across brokers, and if leadership moves to another replica, consumers continue operating in terms of the same topic, partition, and offset space.[^kafka-replication]

So Kafka separates:

```text
physical broker placement
```

from:

```text
topic + partition + offset
```

Consumer progress adds another dimension.

Kafka does not maintain one consumer position for a topic. A committed position belongs to a consumer group and topic partition:

```text
consumer-group
    +
topic
    +
partition
    →
committed offset
```

Kafka stores those committed group offsets in the internal compacted topic `__consumer_offsets`.[^kafka-offset-storage]

For example:

```text
group: payment-processor
topic: payments
partition: 3
committed offset: 10001
```

The committed offset normally represents the **next record to consume**. If the consumer successfully processed record `10000`, it would typically commit `10001`.[^kafka-commit-semantics]

Another consumer group reading the same partition may have a completely different committed position.

This works well inside one Kafka cluster.

Cross-cluster disaster recovery is where things become more interesting.

## Cross-Cluster Recovery Requires Offset Translation

Suppose we have two Amazon MSK clusters:

```text
Primary Region
    ↓
MSK Replicator
    ↓
DR Region
```

MSK Replicator does not copy the source partition log byte for byte. It replicates records into the target cluster and maintains mappings between source and target offsets.[^msk-offset-sync]

The same logical record can therefore have different offsets:

```text
Primary cluster

payments
partition 3
offset 10000
```

and:

```text
DR cluster

payments
partition 3
offset 9873
```

In general:

```text
source offset != target offset
```

So simply copying a consumer group's numerical offset into the DR cluster would be unsafe.

Amazon MSK Replicator instead synchronizes consumer group progress by translating source offsets into corresponding target offsets. It periodically records mappings between the two offset spaces, reads committed consumer group offsets from the source, translates them, and commits the translated positions into the target cluster's `__consumer_offsets` topic.[^msk-offset-sync]

Conceptually:

```text
Source                    Target

1000    ───────────────→   872
1100    ───────────────→   971
1200    ───────────────→  1074
```

A source checkpoint such as:

```text
group: payment-processor
topic: payments
partition: 3
committed offset: 10001
```

might therefore become:

```text
group: payment-processor
topic: payments
partition: 3
committed offset: 9874
```

in the DR cluster.

When the same consumer group starts against DR, it can resume near the equivalent point in the replicated stream.[^msk-offset-sync]

That is a significant DR capability. Amazon MSK is not only replicating records; it can also migrate consumer progress.

There is an important operational constraint. MSK Replicator does not overwrite synchronized offsets for a consumer group that is already active on the target cluster.[^msk-offset-sync] The failover procedure therefore has to coordinate consumer activation with offset synchronization.

The translation is also deliberately approximate.

MSK Replicator records offset mappings periodically rather than maintaining an exact mapping for every record. AWS therefore prefers a translated position that may cause some records to be replayed rather than one that risks skipping records.[^msk-offset-sync]

For example, a source consumer may have progressed through:

```text
10000
```

while the safest translated DR position corresponds to:

```text
9997
```

After failover, the consumer may see the equivalents of `9997`, `9998`, `9999`, and `10000` again.

That is at-least-once behavior, and AWS recommends that consumers tolerate duplicate processing.[^msk-migration]

## Recovery Position Is Not Event Identity

Now consider one of those records:

```json
{
  "eventId": "01KABC...",
  "eventType": "PaymentCompleted",
  "paymentId": "P12345"
}
```

It may exist as:

```text
Primary: payments-3 @ 10000
DR:      payments-3 @ 9873
```

MSK Replicator can translate between those offset spaces well enough to recover the consumer group's position.

But neither offset intrinsically identifies the logical payment event.

That identity comes from the event contract through something such as `eventId` or another stable idempotency key.

This matters when the event has effects outside Kafka.

Suppose `payment-processor` consumes `01KABC` and updates a downstream database. The consumer commits its progress, but before the corresponding checkpoint has fully propagated to DR, the primary Region fails.

The event has reached DR, but the synchronized consumer position is slightly behind.

After failover, `payment-processor` sees `01KABC` again.

Nothing necessarily failed in Kafka or MSK Replicator. The recovery mechanism deliberately resumed from a safe position that avoided skipping records.

The application now has to answer a different question:

```text
Have I already applied event 01KABC?
```

The Kafka offset cannot answer that across arbitrary external side effects.

A stable event identity or idempotency mechanism can.

That is why position and identity are complementary rather than interchangeable:

```text
Position
    → where should I continue?

Identity
    → have I already processed this logical thing?
```

Kafka should not replace offsets with event identifiers. Position is what makes ordered log consumption efficient. Identity becomes important when location and execution history diverge.

Robust recovery often needs both.

## What RPO = 0 Actually Means

This distinction also changes how I think about statements such as:

```text
RPO = 0
```

An RPO of zero means that no state the platform considers successfully committed before the failure may be lost.

For Kafka event data, that means every record acknowledged as successfully committed by the primary platform must still be recoverable after the disaster.

This exposes an important limitation of asynchronous cross-Region replication.

Amazon MSK Replicator copies records asynchronously.[^msk-replicator] A producer can therefore receive an acknowledgement from the primary cluster before that record reaches the DR cluster.

If the primary Region becomes unrecoverable during that interval, strict cross-Region event-data RPO zero cannot be guaranteed by that asynchronous replication path.

A metric such as `MessageLag = 0` tells us that replication has caught up at that point in time. It does not eliminate the replication window for subsequent records.[^msk-monitoring]

It is also important not to confuse three different recovery concerns:

```text
Event missing from DR
    → data loss
    → RPO concern

Consumer checkpoint behind
    → replay
    → recovery-position concern

Business effect repeated
    → duplicate operation
    → application correctness concern
```

A DR cluster can contain every replicated Kafka record while its synchronized consumer position is slightly behind.

The result is replay, not necessarily data loss.

So:

> Replay is not data loss. Consumer-offset lag does not by itself violate the Kafka event-data RPO.

Whether that replay is harmless depends on the consumer application's idempotency guarantees.

## What the MySQL Change Made Me Think About

The recent MySQL change did not introduce GTIDs. What caught my attention was that its newer Change Stream Applier requires GTID-based replication while explicitly leaving file-position replication channels behind.[^mysql-csa]

That reinforces a broader recovery principle:

> Recovery becomes easier when the thing being recovered has an identity independent of the location where it happened to be stored.

Kafka demonstrates why both identity and position matter.

Within one Kafka cluster, physical broker placement is hidden behind the topic-partition-offset abstraction.

Across clusters, the destination has its own log and its own offsets, so consumer progress has to be translated.

And once replay enters the picture, application-level identity becomes important because the system may need to recognize a logical event whose effects have already occurred.

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

Which leaves me with the question that the MySQL change originally triggered:

> Does this checkpoint identify the state I processed, or merely where I should resume looking for it?

---
NOTE: From this post onward, I am going to tag the post where I used AI assitance for anything - review, dedupe, etc. I am honestly not waiting for humans to review and then publish. ChatGPT essentially has removed the review barrier and I am getting much better reviews than before. When I asked ChatGPT to score my intitial draft, it scored it 6/10 and suggested improvements. After improvements it says it is 8/10. I will take it. :)
---

[^mysql-csa]: Oracle, "Changes in MySQL 26.7.0 (2026-07-28)," *MySQL 26.7 Release Notes*. The release introduces the Change Stream Applier and lists file-position replication channels, GTID modes other than `ON`, and `GTID_ONLY=0` among unsupported configurations. <https://dev.mysql.com/doc/relnotes/mysql/26.7/en/news-26-7-0.html>

[^mysql-gtid]: Oracle, "GTID Format and Storage," *MySQL Reference Manual*. MySQL defines a GTID as a unique identifier associated with a transaction committed on its originating server and states that replicated transactions retain the same GTID. <https://dev.mysql.com/doc/refman/9.1/en/replication-gtids-concepts.html>

[^mysql-gtid-failover]: Oracle, "Replication with Global Transaction Identifiers," *MySQL Reference Manual*. MySQL documents that GTID-based replication removes the need to refer to binary log files and positions when starting a replica or failing over to a new source. <https://dev.mysql.com/doc/refman/9.4/en/replication-gtids.html>

[^kafka-replication]: Apache Kafka, "Replication," *Kafka Design Documentation*. Kafka partitions are replicated across brokers, with one replica acting as leader and other replicas able to take over leadership. <https://kafka.apache.org/documentation/#replication>

[^kafka-offset-storage]: Apache Kafka, "Consumer Offset Tracking," *Kafka Implementation Documentation*. Kafka documents that consumer offsets are maintained for consumer groups and that offset commits are stored in the compacted `__consumer_offsets` topic. <https://kafka.apache.org/42/implementation/distribution/>

[^kafka-commit-semantics]: Apache Kafka, `KafkaConsumer` API documentation. The consumer API specifies that a committed offset should identify the next record to be processed rather than the offset of the record just processed. <https://kafka.apache.org/42/javadoc/org/apache/kafka/clients/consumer/KafkaConsumer.html>

[^msk-offset-sync]: Amazon Web Services, "Consumer group offset synchronization," *Amazon MSK Developer Guide*. AWS documents source-to-target offset mapping, translation of consumer group offsets, target offset commits, approximate translation, and restrictions when the target consumer group is active. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-bidirectional-offset-sync.html>

[^msk-migration]: Amazon Web Services, "Migrate between Amazon MSK clusters," *Amazon MSK Developer Guide*. AWS notes the at-least-once characteristics of replication and recommends consumers be able to handle duplicate messages. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-migrate-cluster.html>

[^msk-monitoring]: Amazon Web Services, "Monitor an MSK Replicator," *Amazon MSK Developer Guide*. AWS exposes metrics for replication lag and consumer group offset synchronization. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-monitor.html>

[^msk-replicator]: Amazon Web Services, "What is Amazon MSK Replicator?" *Amazon MSK Developer Guide*. AWS describes MSK Replicator as an asynchronous replication capability for Amazon MSK clusters. <https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator.html>