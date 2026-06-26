---
layout: post
title: "Git Worktree and the Myth of a Single Working Directory"
date: 2026-06-25
categories:
  - Technology
  - Software Engineering
tags:
  - git
  - version-control
  - software-engineering
author: Palak Mathur
toc: true
---

While working on a feature recently, I needed to look at something on another branch. Normally this would involve one of the workflows most Git users are familiar with: commit the current changes, stash them, or temporarily abandon the current state and switch branches. None of those options felt appealing. The work was incomplete and I was not ready to commit it. Stashing would have worked, but it felt like introducing additional state that I would need to remember to restore later.

Looking for alternatives, I came across a Git feature that I had heard about before but never used seriously: worktree. At first glance, worktree looks like a convenience feature. It allows multiple working directories to be attached to the same repository so that different branches can be checked out simultaneously. That is useful on its own, but what caught my attention was the implication behind it.

Most Git users, myself included, tend to think of a repository as a working directory that happens to contain a `.git` directory. Git does not view things this way. From Git's perspective, the repository is the object database, and the working directory is one view into that repository. Worktree exists because Git was never fundamentally limited to a single working directory. Most of us simply use it that way.

## The Mental Model Most of Us Carry

Consider a typical repository:

```
my-project/
├── src/
├── docs/
├── pom.xml
└── .git/
```

Most developers naturally view this as a single unit: a repository, a working directory, and a currently checked-out branch. That mental model is not wrong, but it is incomplete. The branch is not stored in the working directory. The commit history is not stored in the working directory. The object database is not stored in the working directory. Those things live inside `.git`, and the files visible in the working directory are a projection of a particular commit from the repository.

Once viewed from that perspective, an interesting question emerges: why should a repository be limited to a single projection? Git's answer is that it isn't.

## Creating a Worktree

Suppose the current repository is checked out on a feature branch:

```
git switch feature/customer-notifications
```

A second working directory can be created using:

```
git worktree add ../customer-notifications-main main
```

Git creates a new directory alongside the existing one:

```
projects/
├── customer-notifications/
└── customer-notifications-main/
```

The first directory remains on the feature branch, and the second is checked out on `main`. Both can be opened in separate terminals, editors, or IDE windows, and changes in one working tree do not affect the other. From a developer's perspective, it feels almost like having two clones, except that Git is not creating another repository.

## Looking at What Git Actually Creates

After creating a worktree, the repository structure changes slightly. Inside `.git`, a new directory appears:

```
.git/
├── objects/
├── refs/
├── logs/
└── worktrees/
```

Listing the contents of `.git/worktrees/` reveals a subdirectory for each additional worktree, containing files such as `HEAD`, `gitdir`, `commondir`, and `index`. The exact contents may vary across Git versions, but the important observation is that Git is maintaining metadata for an additional working tree while continuing to share the underlying repository. This is why creating a worktree is extremely fast. Git is not duplicating the commit graph, objects, tags, or references. It is creating another working directory and associating it with the existing repository.

## Shared and Separate State

The easiest way to understand worktrees is to identify what is shared and what is independent. The object database, branch references, tags, hooks, and configuration are all shared across worktrees. Each worktree has its own working directory contents, its own index, and its own HEAD pointing somewhere into the shared `refs/heads/`. This separation is what allows two branches to be active simultaneously without two repositories, and it has a few practical consequences worth noting.

A `git fetch` in any worktree updates the shared refs, so the new commits are immediately visible from every worktree attached to the repository. Hooks installed in `.git/hooks/` run regardless of which worktree triggered them, which catches some people out when they expect per-worktree hook behavior. And because branch refs are shared, a branch checked out in one worktree cannot be checked out in another, which is the next thing worth looking at.

## Why Git Refuses Certain Operations

Suppose `feature/customer-notifications` is already checked out in one worktree. Attempting to check it out in another produces an error:

```
$ git worktree add ../another-copy feature/customer-notifications
fatal: 'feature/customer-notifications' is already checked out at '/path/to/customer-notifications'
```

This can initially seem restrictive, but the restriction makes sense given the shared-ref design. A branch is a movable reference, and if two working directories could manipulate the same branch independently, Git would have no way to determine the intended state of that reference. The restriction prevents ambiguity and protects branch state from concurrent updates.

## Worktree Versus Stash

Worktree and stash solve different problems, even though both come up when someone needs to switch context briefly. A stash temporarily preserves uncommitted changes so another task can be performed in the same working directory, while a worktree creates an entirely separate workspace. If I need to quickly pull `main`, perform a rebase, and continue working, a stash is reasonable. If I expect to spend hours investigating another branch while keeping the current work untouched, a worktree is the better choice. The distinction is subtle but important: a stash preserves state, while a worktree preserves context.

## Worktree Versus Another Clone

Historically, some developers solved this problem by maintaining multiple clones of the same repository. That approach works, but every clone maintains its own object database, references, and repository metadata, which means fetches must be performed in each clone separately and disk usage grows linearly with the number of copies. Worktrees share those resources. For smaller repositories the difference is negligible, but for larger repositories containing years of history it becomes noticeable. More importantly, worktrees communicate intent. They represent multiple views into the same repository rather than multiple copies of the repository itself.

## The Bare Repository Approach

One workflow worth mentioning treats worktrees as the primary interface rather than an occasional convenience. The repository is cloned bare, and every branch the developer wants to work on becomes its own worktree:

```
git clone --bare git@github.com:example/project.git project.git
cd project.git
git worktree add ../project-main main
git worktree add ../project-feature feature/customer-notifications
```

There is no "main" working directory in this model. Every working directory is a worktree, and the bare repository at the root contains only the shared state. Some developers organize their worktrees inside a `.worktrees/` subdirectory of the project to keep things tidy. Whether this layout is worth adopting depends on how often parallel branches are needed, but it makes Git's underlying model unusually visible.

## Managing Worktrees

Git provides a few commands for managing worktrees. `git worktree list` shows all active worktrees and the branches they point to:

```
/home/palak/projects/my-project          a1b2c3d [feature/customer-notifications]
/home/palak/projects/my-project-main     e4f5g6h [main]
```

`git worktree remove <path>` removes a worktree. If a worktree directory is removed manually outside of Git, the stale metadata can be cleaned up with `git worktree prune`. Most day-to-day usage rarely requires anything beyond these commands.

## Final Thoughts

Before learning about worktrees, I implicitly assumed that a Git repository and a working directory were inseparable concepts. Git itself makes no such assumption. A repository is an object database containing commits, trees, blobs, references, and metadata, while a working directory is one representation of repository state at a particular point in time. Viewed from that perspective, worktrees feel less like an advanced feature and more like a natural consequence of Git's architecture.

The feature is useful for avoiding branch switching, preserving context, and keeping parallel streams of work isolated. But the more interesting lesson is the one it reveals about Git itself. Many of the limitations we assume are built into our tools are actually limitations of the mental models we carry around. Git worktree is a small reminder that those two things are not always the same.
