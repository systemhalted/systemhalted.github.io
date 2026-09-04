---
layout: post
title: "Resource Integrity Belongs to the Resource, Not the API"
date: 2026-08-25
categories:
  - Software Engineering
tags:
  - REST
  - API Design
  - Platform Engineering
  - Domain-Driven Design
  - Operational Tooling
comments: true 
description: "An operational tool may bypass a REST endpoint, but it must not bypass the resource contract."
---

Let's assume that a platform exposes a REST API for creating and managing resources. Over time, the platform team also builds administrative scripts, migration utilities, recovery procedures, scheduled jobs, and internal operational tools.

These tools may not call the REST API. Sometimes that is reasonable. A recovery utility may need to work when the API is unavailable. A migration may require capabilities intentionally excluded from the public interface. An operator may need to repair partially provisioned infrastructure.

But bypassing the API must not mean bypassing the resource contract.

The governing principle is simple:

> Resource integrity belongs to the resource, not to the API.

Every mechanism that creates, changes, or deletes a platform-owned resource must preserve the same resource identity, lifecycle rules, domain invariants, and required side effects. This remains true whether the operation originates from a REST endpoint, an administrative tool, an automation job, a migration, or a recovery procedure.

## REST Does Not Own the Resource

REST stands for **Representational State Transfer**. Its uniform-interface constraints include identifying resources and manipulating them through representations.[^1] A resource has an identity, commonly exposed through a URI, and a client exchanges representations of its state.[^2]

Consider a Kafka topic managed by an event-streaming platform:

```text
/topics/customer-events
```

The topic is the resource. The following JSON is one representation of its current state:

```json
{
  "name": "customer-events",
  "partitions": 12,
  "retentionHours": 168,
  "status": "ACTIVE"
}
```

Changing `retentionHours` does not necessarily create a new resource. The resource retains its identity while its state changes.

I know many architects and engineers think of the REST endpoint as the resource unto itself, and at one point I was one of them. My reasoning was simple, the resource should have one identity, and anything that needs to interact with the resource should interact through that single identity. I once treated the API path as the resource’s canonical identity and concluded that every mutation had to pass through it. That conflated the resource with one interface used to reach it.

Of late, I have come to realize that the REST endpoint is not the resource. Nor is it a representation of the resource. The URI identifies the target resource, while the request and response payloads carry representations of its current or intended state. The API is the interaction boundary through which clients act upon that resource. The database row is not necessarily the resource either. Nor is the corresponding Kafka topic by itself. Within the platform’s control-plane model, the managed-topic resource is not necessarily identical to the physical Kafka topic. It may be a higher-level entity encompassing desired configuration, ownership, policies, provisioned infrastructure, lifecycle state, and audit history.

If the API disappears temporarily, the resource does not stop existing. If a tool avoids the API, it does not gain the right to redefine what constitutes a valid resource.

## A Resource Is More Than Stored State

Suppose the platform’s topic-creation API performs the following work:

1. Validates the topic name and configuration.
2. Confirms that the caller is authorized for the owning domain.
3. Prevents duplicate creation through idempotency controls.
4. Provisions the physical topic in MSK.
5. Applies retention, encryption, and access policies.
6. Stores the platform’s metadata.
7. Publishes a lifecycle event.
8. Records an auditable history of the operation.

An administrative script that inserts a row directly into the metadata database has not necessarily created the same resource. It may only have created the appearance of one.

The platform could now report that the topic exists even though the physical topic was never provisioned. Alternatively, the physical topic might exist without the correct policies, ownership information, or audit record. Each subsystem may be locally correct while the platform resource is globally inconsistent. This is a recurring distributed-systems problem: coordinating state across multiple components introduces partial-failure and consistency concerns that cannot be reduced to one database write.[^3]

That is the danger of treating the API implementation as the only place where integrity matters. Validation, authorization, provisioning, event publication, and auditing are not incidental HTTP behavior. They are parts of the resource’s lifecycle.

## State Changes; Invariants Must Hold

The resource’s state must remain pristine in the sense that its **integrity** remains valid.

State is expected to change. A topic can move from `PROVISIONING` to `ACTIVE`, its retention period can be updated, and it may eventually move to `DELETING` and `DELETED`. The requirement is not to keep the original state untouched. The requirement is to ensure that every transition leaves the resource in a valid and internally consistent condition.

For a platform-managed topic, the invariants might include:

- A globally unique and stable resource identifier exists.
- The resource always has an accountable owner.
- Platform metadata corresponds to the provisioned infrastructure.
- Security and retention policies conform to platform rules.
- Lifecycle transitions follow an allowed state machine.
- Concurrent changes cannot silently overwrite each other.
- Material changes are authorized and auditable.
- Required events are published exactly as promised by the platform contract.

These invariants apply to all mutation paths. The origin of a command does not alter the definition of a valid topic. In domain-driven terms, invariants belong inside the model boundary that controls valid state transitions, not exclusively inside one delivery mechanism.[^4] Every mutation path must preserve the resource’s identity and domain invariants while honoring the applicable transition guards, audit requirements, side-effect obligations, and recovery guarantees.

## The API Should Be an Adapter, Not the Domain

A robust design does not force every internal actor to communicate over HTTP merely to reuse business rules. Instead, it separates the REST adapter from the application operations that govern the resource. This follows the Ports and Adapters model, in which HTTP, batch processes, tests, and other programs can drive the application through different adapters without moving the application rules into those adapters.[^5]

```text
REST API ───────────┐
Admin CLI ──────────┤
Scheduled job ──────┼──> Application command ──> Domain rules and lifecycle
Migration utility ──┤
Recovery workflow ──┘
```

The REST controller translates an HTTP request into an application command. An administrative CLI may translate operator input into the same command. A scheduled reconciliation job may invoke a related command with a different authorization context. The interfaces differ, but the resource rules remain centralized and consistent.

This does not imply that every tool must execute precisely the same workflow. Operational tools sometimes need privileged operations. A migration may intentionally suppress a notification. A repair tool may reconstruct missing metadata from the physical infrastructure. A disaster-recovery process may operate while dependent systems are unavailable.

Those differences should be explicit parts of the operational contract, not accidental consequences of writing directly to storage. A privileged operation still needs defined preconditions, postconditions, authorization, auditability, and reconciliation behavior.

## Direct Changes Are Break-Glass Operations

There will be situations where neither the API nor the normal application command path is usable. Direct database or infrastructure changes may then be necessary.

Such changes should be treated as break-glass operations rather than ordinary administration. The need for authorized changes, configuration-change control, and audit-record generation is also reflected in NIST's security-control catalog [^6]. At minimum, the procedure should define:

- Who may authorize and execute the change.
- Which invariants may be temporarily violated.
- How the original and resulting states are recorded.
- How dependent state and lifecycle events are repaired.
- How the platform verifies convergence afterward.
- How the operation is made safe to retry or reverse.

The distinction is important. An emergency exception does not invalidate the resource contract. It creates an obligation to restore it.

## What This Means for Platform Teams

When reviewing an operational tool, asking whether it uses the REST API is useful but insufficient. The better questions are:

1. Does it operate on the same resource identity?
2. Does it enforce the same domain invariants?
3. Does it respect the lifecycle state machine?
4. Does it reproduce or deliberately account for required side effects?
5. Does it preserve authorization, concurrency control, and auditability?
6. Can the platform detect and reconcile partial failure?

This framing also clarifies ownership. If a team owns the platform resource, it owns more than the public API. It owns the meaning and integrity of that resource across every supported way it can be changed.

## The Principle

A REST API is an interaction boundary through which representations are exchanged. It is not the sole guardian of the underlying resource.

Operational tools may legitimately use a different interface. They may require elevated capabilities, alternate workflows, or direct access during exceptional circumstances. But a different mutation path does not create a different definition of the resource.

The architectural rule is therefore:

> Bypassing the API is sometimes necessary. Bypassing the resource contract is not.

When this rule is applied consistently, administrative tools stop being dangerous collections of privileged shortcuts. They become deliberate participants in the platform’s resource lifecycle.

-----
[^1]: Roy T. Fielding, ["Representational State Transfer (REST)," Chapter 5 of *Architectural Styles and the Design of Network-based Software Architectures*](https://ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm), 2000, especially Sections 5.1.5 and 5.2.1. See also Roy T. Fielding and Richard N. Taylor, ["Principled Design of the Modern Web Architecture"](https://doi.org/10.1145/514183.514185), *ACM Transactions on Internet Technology* 2, no. 2 (2002): 115–150.

[^2]: IETF, [RFC 9110: *HTTP Semantics*](https://www.rfc-editor.org/rfc/rfc9110.html), 2022, Sections 3.1 and 3.2. The standard distinguishes a resource from a representation reflecting its past, current, or desired state.

[^3]: Martin Kleppmann, *Designing Data-Intensive Applications* (O’Reilly Media, 2017), particularly the discussions of distributed transactions, partial failure, and consistency.

[^4]: Eric Evans, *Domain-Driven Design: Tackling Complexity in the Heart of Software* (Addison-Wesley, 2003), particularly the treatment of entities, aggregates, and invariants.

[^5]: Alistair Cockburn, ["Hexagonal Architecture: The Original 2005 Article"](https://alistair.cockburn.us/hexagonal-architecture), 2005. Cockburn describes application ports driven by users, HTTP interfaces, batch scripts, automated tests, or other programs through different adapters.

[^6]: NIST, [*Security and Privacy Controls for Information Systems and Organizations*, SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final), 2020, particularly CM-3 (Configuration Change Control), CM-5 (Access Restrictions for Change), and AU-12 (Audit Record Generation).
