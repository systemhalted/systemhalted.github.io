---
layout: post
title: "JPMS and Cargo: Two Answers to the Same Problem"
date: 2026-07-12
categories: [java, rust, programming-languages]
tags: [jpms, cargo, modules, encapsulation, type-systems]
comments: true
toc: true
description: The same project built twice, in Java (JPMS + Maven) and Rust (Cargo) — how each answers compilation, distribution, and encapsulation, why a crate maps to a JPMS module and a Rust module to a Java package, and where the analogy breaks down.
---

Every language with a serious ecosystem eventually has to answer three related questions:

1. How is code compiled?
2. How is it distributed?
3. Where is encapsulation enforced?

Java accumulated its answers over time. Source files and packages came from the language, JARs became the distribution unit, and JPMS arrived in 2017 to add strong encapsulation and explicit dependency readability.

Rust and Cargo started with a more integrated model, designed together around a standard package and build system.

The two systems answer the same three questions but put the answers in different places. Java spreads them across pieces assembled over two decades — packages and the module system in the language, JARs and Maven outside it — that must stay consistent without anything forcing them to. Rust concentrates compilation and encapsulation in the crate and distribution in the Cargo package, with far less overlap.

## The terms

Both toolchains reuse a few of the same words for different things, so it helps to fix the vocabulary before the code.

**Rust / Cargo**

- **Crate** — the unit the compiler compiles, and the unit of encapsulation. A crate is either a *library crate* or a *binary crate*.
- **Package** — what Cargo versions, builds, and publishes, described by `Cargo.toml`. A package holds at most one library crate and any number of binary crates.
- **Module** (`mod`) — a namespace *inside* a crate. Modules form a tree, and that tree is where visibility is enforced.
- **Workspace** — a set of packages that share one `Cargo.lock` and one build.

**Java / Maven / JPMS**

- **Package** — a namespace declared per source file (`package in.systemhalted.gateway.api;`).
- **Module (JPMS)** — a named group of packages with a `module-info.java` that declares what it reads and what it exports. The unit of strong encapsulation.
- **Artifact (Maven)** — the versioned, publishable unit, identified by `groupId:artifactId:version` and shipped as a JAR.
- **JAR** — the packaging and distribution format.

**Shared**

- **Dependency** — code from another package, artifact, crate, or module that this component uses. Maven resolves and fetches a Java dependency, while JPMS separately determines module readability through `requires`. Cargo resolves a Rust dependency and makes the corresponding crate available to the compiler from the same manifest declaration.

The words already collide. A Rust *crate* is closest to a JPMS *module*, a Rust *module* to a Java *package*, and a Cargo *package* to a Maven *artifact*. None of these is exact — a crate resembles a JPMS module in encapsulation and dependency structure more than in the mechanics of compilation — and "module" means almost opposite-scale things in the two worlds. The rest of this post lines these up against the three questions and shows where the words look alike but aren't.

## The same project, twice

Consider a small API gateway library with a public API, a configuration type, and an internal routing engine.

Here is the Java version, built with Maven and JPMS:

```text
gateway/
├── pom.xml
└── src/main/java/
    ├── module-info.java
    └── in/systemhalted/gateway/
        ├── api/
        │   └── RouteHandler.java
        ├── config/
        │   └── GatewayConfig.java
        └── internal/
            └── Router.java
```

And the Rust version:

```text
gateway/
├── Cargo.toml
└── src/
    ├── lib.rs
    ├── api.rs
    ├── api/
    │   └── handlers.rs
    ├── config.rs
    ├── internal.rs
    └── internal/
        └── router.rs
```

Four files reveal most of the architectural difference: `pom.xml`, `module-info.java`, `Cargo.toml`, and `lib.rs`. They do not map one-to-one. Understanding why is most of understanding the two systems.

## The four files

### pom.xml: identity and dependencies

The POM belongs to Maven, not to the Java language. It declares the artifact's coordinates and the dependencies required to build it:

```xml
<groupId>in.systemhalted</groupId>
<artifactId>gateway</artifactId>
<version>1.4.0</version>
<dependencies>
    <dependency>
        <groupId>com.fasterxml.jackson.core</groupId>
        <artifactId>jackson-databind</artifactId>
        <version>2.17.1</version>
    </dependency>
</dependencies>
```

Maven resolves the dependency, downloads the JAR, and constructs the classpath or module path. `javac` knows nothing about the POM.

### module-info.java: readability and exports

The module descriptor lives at the root of the Java source tree, at `src/main/java/module-info.java`. It is part of the Java language and is compiled by `javac`.

```java
module in.systemhalted.gateway {
    requires com.fasterxml.jackson.databind;
    exports in.systemhalted.gateway.api;
    exports in.systemhalted.gateway.config;
    // in.systemhalted.gateway.internal is not exported
}
```

The descriptor declares two boundaries: which modules this module reads, and which packages it exposes.

Jackson therefore appears twice. The POM tells Maven to obtain the JAR; the descriptor tells JPMS that this module may read it. These are separate systems, and nothing forces them to agree: a dependency can sit on the module path without a matching `requires`, or be declared with `requires` without being supplied by the build. The two names even differ — the Maven artifactId is `jackson-databind`, the JPMS module name `com.fasterxml.jackson.databind`. Coordinate and module identity are separate namespaces.

### Cargo.toml: the package manifest

`Cargo.toml` describes the Cargo package:

```toml
[package]
name = "gateway"
version = "1.4.0"

[dependencies]
serde_json = "1"
```

The `gateway` package here is a single library crate, `src/lib.rs`. Add a `src/main.rs` and it would hold two crates, a library and a binary. The crate is where visibility and module boundaries apply.

Declaring a dependency in `Cargo.toml` both resolves it and makes it available during compilation; Cargo invokes `rustc` with the corresponding `--extern` arguments. There is no separate language-level file holding a second copy of the dependency declaration.

### lib.rs: the crate root

`lib.rs` is not a manifest. It is source code — the root of the library crate and the starting point of the crate's module tree:

```rust
// src/lib.rs
pub mod api;
pub mod config;
mod internal;
```

`pub mod api;` loads `src/api.rs` and makes the module publicly reachable; `mod internal;` loads `src/internal.rs` but does not make it reachable outside the crate.

This is where part of the Java module descriptor's role moves into source. The descriptor's `exports in.systemhalted.gateway.api;` and the crate root's `pub mod api;` are not exact equivalents, but serve the same purpose: defining the externally reachable surface. In Rust the dependency side lives in `Cargo.toml`, the visibility side in ordinary source.

## Where the module tree comes from

The deeper difference is not the file names. It is who defines the structure.

### Java packages are declared independently

Every Java source file declares its package, such as `package in.systemhalted.gateway.internal;`. Build tools conventionally mirror that name in the source directory, as `in/systemhalted/gateway/internal/Router.java`. But the package declaration defines membership: no parent package registers the class, and no other source file has to mention it.

A Java package is a flat namespace. The dots suggest hierarchy, but there is none: `a.b` and `a.b.c` are separate packages, and `a.b.c` is not semantically nested inside `a.b`.

### Rust modules form an explicit tree

In Rust, a file does not join the crate merely by existing on disk; a parent module must declare it. In `src/lib.rs`, `mod internal;` brings `src/internal.rs` into the crate. In turn, `src/internal.rs`'s `pub mod router;` brings `src/internal/router.rs` into the tree, and `src/api.rs`'s `pub mod handlers;` brings `src/api/handlers.rs`. Remove the `mod router;` declaration and the compiler never reads `router.rs`, even if the file remains on disk. The filesystem follows the module tree; it does not create it.

This explains why the layout carries both `internal.rs` and an `internal/` directory: `internal.rs` defines the module, `internal/` holds its child modules. A leaf module such as `config` needs only `config.rs`. The older `internal/mod.rs` layout still works, but the `internal.rs`-plus-`internal/` style is now common.

## Visibility follows the tree

Once the tree exists, visibility is evaluated along paths through it. Consider:

```rust
// src/internal/router.rs
pub struct Router { /* ... */ }

pub(crate) fn rebuild_routes() {
}

pub(super) fn debug_dump() {
}

pub(in crate::internal) fn merge() {
}

fn parse_segment() {
}
```

These declarations represent different visibility scopes.

### pub is bounded by the path

This is the first rule that often surprises Java developers. `pub struct Router;` does not necessarily make `Router` reachable outside the crate; every module along the path must also be public. The full path is `crate::internal::router::Router`, but `lib.rs` declared `mod internal;`, not `pub mod internal;`. The private `internal` module blocks the path: `Router` is public within the visibility that path allows, but the path itself is not externally reachable.

Visibility belongs to both the item and its route through the module tree.

### Visibility can name an ancestor

Rust can express scopes relative to the tree: `pub(crate)` is visible throughout the crate, `pub(super)` within the parent module and its descendants, `pub(in crate::internal)` within the named module and its descendants. The path in `pub(in path)` must name an ancestor of the current module. A function inside `crate::internal::router` cannot declare `pub(in crate::api)`, because `api` is a sibling branch, not an ancestor.

Java has no equivalent, because its packages do not form a semantic tree. For top-level types and cross-package access, Java mainly offers `public` and package-private; class members also have `private` and `protected`, but none express visibility to a named package subtree.

Before JPMS, a package named `internal` was mostly a warning:

> This is internal. Please do not use it.

JPMS made that boundary enforceable across modules by withholding exports. But inside the module, Java remains flat.

### Visibility, keyword by keyword

External reachability is path-based in Rust and package-based in JPMS. Each Rust modifier grants a scope defined by the module tree; the nearest Java construct is often not a keyword at all, because Java expresses external reachability through the module descriptor rather than a modifier on the declaration.

| Rust modifier | Scope it grants | Nearest Java equivalent |
|---------------|-----------------|-------------------------|
| `pub` on a public path | outside the crate | `public` in an exported package |
| `pub` behind a private path | capped by the path | `public` in a non-exported package |
| `pub(crate)` | entire crate | `public` in a non-exported package |
| `pub(super)` | parent module's subtree | none |
| `pub(in path)` | named ancestor's subtree | none |
| no modifier | current module and descendants | package-private, approximately |

Java approximates `pub(crate)` by placing a `public` class in a package omitted from exports — not a Java visibility level, but an effect of the module boundary. Rust privacy also differs from Java package privacy: a private Rust item is visible to its defining module and that module's descendants, while a package-private Java member is visible to all code in the same package.

## Imports reveal the architecture

The different namespace models also shape imports.

Java:

```java
import java.util.List;
import in.systemhalted.gateway.api.RouteHandler;
```

Rust:

```rust
// src/internal/router.rs
use std::collections::HashMap;
use crate::api::RouteHandler;
```

And from a child module, `use super::Router;`.

A Java import aliases a fully qualified name. That name belongs to a global package namespace and says nothing about where the importing class sits relative to the imported one. There is no Java equivalent of `super::`, because Java packages have no parent-child relationship.

A Rust `use` navigates the module tree:

- `crate::` starts at the crate root
- `self::` starts at the current module
- `super::` starts at the parent module
- an external crate is named directly

The module tree is therefore more than an encapsulation mechanism. It is the coordinate system for names throughout the crate.

## Re-exports and transitive readability

Rust and JPMS both allow one component's API to depend on another, but the mechanisms are very different.

### JPMS propagates readability

```java
module in.systemhalted.gateway.api {
    requires transitive in.systemhalted.gateway.types;
}
```

Any module that requires `gateway.api` also reads `gateway.types`, without declaring `gateway.types` itself. The dependency remains a separate module: its classes keep their original package and module identity, and consumers can access only the packages that `gateway.types` exports. `requires transitive` changes the readability graph.

### Rust republishes names

In `src/lib.rs`, `pub use gateway_types::RouteConfig;` gives consumers a public path through the current crate, `gateway::RouteConfig`. Rust can also re-export an item from a private internal module with `pub use crate::internal::router::Router;`: the internal module remains private, but `Router` becomes available at `gateway::Router`.

This works because `Router` is public and reachable from `lib.rs`. A re-export cannot override privacy; it can only republish an item the re-exporting module can already access.

This gives Rust an important form of indirection: the implementation can live at `crate::internal::router::Router` while the public API stays `gateway::Router`, and the internal module tree can change without changing the path exposed to consumers.

Java cannot do this directly, because a class's package is part of its identity.

## Scaling up: modules and workspaces

Real projects rarely remain a single component. Suppose the gateway is split into two libraries, `gateway-api` and `gateway-core`.

### Maven multi-module build

```text
gateway/
├── pom.xml
├── gateway-api/
│   ├── pom.xml
│   └── src/main/java/
│       ├── module-info.java
│       └── in/systemhalted/gateway/api/
└── gateway-core/
    ├── pom.xml
    └── src/main/java/
        ├── module-info.java
        └── in/systemhalted/gateway/core/
```

The root POM aggregates the modules:

```xml
<packaging>pom</packaging>
<modules>
    <module>gateway-api</module>
    <module>gateway-core</module>
</modules>
```

`gateway-core` declares the Maven dependency in its POM and the JPMS dependency in its module descriptor.

### Cargo workspace

```text
gateway/
├── Cargo.toml
└── crates/
    ├── gateway-api/
    │   ├── Cargo.toml
    │   └── src/
    │       └── lib.rs
    └── gateway-core/
        ├── Cargo.toml
        └── src/
            └── lib.rs
```

The root manifest defines the workspace:

```toml
[workspace]
members = ["crates/*"]
```

`gateway-core` declares a path dependency:

```toml
[dependencies]
gateway-api = { path = "../gateway-api" }
```

The `crates/` directory is only convention; the `members` declaration defines the workspace. Each member remains a normal Cargo package with its own manifest, source tree, and crate root. A workspace adds organization above packages without weakening the boundaries between their crates.

### Dependency management

The Maven and Cargo mappings are close but not identical. A Cargo workspace shares one resolved dependency graph through `Cargo.lock`. Centralized dependency declarations belong in `[workspace.dependencies]`, and member packages inherit them with `serde = { workspace = true }` — closer to Maven's `dependencyManagement` than the lock file itself.

At the build level, both construct a dependency graph and build components in order: `cargo build` from the workspace root resembles a Maven reactor build like `mvn package` from the parent project.

The architectural consequence is the same: a crate boundary inside a workspace is still a real boundary. `gateway-core` sees only what `gateway-api` exposes publicly, just as one JPMS module sees only the packages another exports. Splitting a project into crates or JPMS modules is therefore not directory organization; it changes the enforceable architecture.

## Split packages and legacy constraints

JPMS arrived after two decades of classpath-based Java. That history created migration mechanisms and compatibility layers:

- automatic modules
- the unnamed module
- classpath fallback
- command-line overrides
- split-package failures

A split package occurs when two or more named modules define types in the same Java package. JPMS rejects that arrangement: a given package must belong to a single module. Rust rules out the analogous structure by construction — a Rust module belongs to one crate's module tree and is introduced by declarations within that crate. No module spans two crates. There is no pre-crate Rust ecosystem to accommodate.

The escape hatch survives, too. Drop a JAR onto the legacy `--class-path` instead of the module path and its packages fall back into the unnamed module, outside JPMS entirely — strong encapsulation holds only as long as everyone stays on the module path. Rust has no such fallback: nothing sits outside the crate system, so its boundaries always hold.

This is not evidence that Rust's designers were smarter; they had a different starting point. But the consequence matters: crate boundaries apply uniformly across the ecosystem, and tools can assume the model is real.

## The runtime model

JPMS also governs deep runtime reflection. Java frameworks often inspect constructors, fields, and methods reflectively; whether that access is permitted depends on ordinary access checks and whether the containing package is open. A module can open one package to a specific framework:

```java
module in.systemhalted.gateway {
    opens in.systemhalted.gateway.config
        to com.fasterxml.jackson.databind;
}
```

The command line can also modify the boundary with `--add-opens`.

Rust has no general runtime reflection facility comparable to Java reflection. Its major metaprogramming mechanisms — procedural macros and derive macros — operate during compilation, expanding into ordinary Rust code that remains subject to the language's visibility rules. Rust therefore needs no equivalent of JPMS `opens`; the problem does not arise, because the runtime model is different.

## The mapping

| Rust | Java | Caveat |
|------|------|--------|
| crate | JPMS module | Architectural analogy focused on encapsulation and dependency structure |
| Cargo package | Maven artifact | Manifest and publishing unit; may contain multiple crates |
| workspace | Maven multi-module build | Workspace manifest resembles an aggregator parent POM |
| `[workspace.dependencies]` | `dependencyManagement` | Centralized dependency declarations |
| `Cargo.toml` dependencies | POM dependencies plus JPMS `requires` | Cargo combines resolution and compiler availability; Java separates them |
| Rust module | Java package | Rust modules form a tree; Java packages are flat |
| `use` | `import` | Rust navigates a module tree; Java aliases package-qualified names |
| `pub use` | no direct equivalent | Re-exports create new public paths |
| `requires transitive` | no direct Rust equivalent | Propagates module readability |
| none | `opens`, `--add-opens` | Rust has no comparable runtime-reflection model |

## What each language should envy

Return to the three questions. Rust answers all of them inside the language and its build tool, the same way for every crate. Java answers them across pieces assembled over twenty years. That difference is the source of what each side can envy.

Java developers should envy Rust's uniformity. Every Rust crate, from the standard library to a small third-party library, participates in the same crate and module model. There is no parallel classpath world, no automatic-module transition state, no split-package compatibility problem, and no reflective framework asking for runtime access to private implementation details.

Rust developers should envy the explicit JPMS boundary document. A `module-info.java` file states, in one compact artifact:

- which modules are readable
- which packages are exported
- which packages are opened
- which services are used or provided

Cargo can expose the resolved dependency graph through `cargo metadata`, and Rust tooling can resolve public re-exports, but a crate's external namespace is assembled through source declarations rather than summarized in one descriptor. For architectural governance at module and package granularity, JPMS provides a cleaner artifact.

Neither system describes the complete public API: an exported Java package still has to be inspected for its public classes and methods, and a Rust crate still has to be analyzed for its public items and re-exports. But JPMS makes the high-level boundary unusually explicit.

Rust could make the crate the language's central architectural unit, and Cargo built its package and dependency model around it: one place answers compilation and encapsulation, one place answers distribution. JPMS had no such freedom. It had to coexist with packages, JARs, the classpath, reflection-heavy frameworks, and two decades of existing code; its answers to the three questions were already spread apart before it arrived.

That historical constraint explains most of the irregularity in JPMS. It also explains most of the uniformity in Cargo.
