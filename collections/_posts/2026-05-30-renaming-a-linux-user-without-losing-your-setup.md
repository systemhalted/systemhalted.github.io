---
layout: post
title: Renaming a Linux User Without Losing Your Setup
date: 2026-05-30 16:30:00 +0530
categories:
- Technology
- Software Engineering
tags:
- linux
- ubuntu
- sysadmin
- usermod
- technology
- software
author: Palak Mathur
toc: true
---

When I installed Ubuntu on a spare laptop, my intent was to make it usable for my son. 
So, I named the account `old-user` (obfuscated for obvious reasons). However, my son
moved on and took my old MacBook Pro, leaving this laptop for me. The first thing I wanted to 
do was personalize it by renaming the account to `systemhalted` everywhere: login name, home 
directory, primary group, and the name shown on the GNOME login screen.

I wanted to do this without losing my existing shell configuration, installed tools, IDE state, 
and Claude Code session history.

It turns out a complete rename is very doable. The data-loss fear is mostly misplaced. The real
risk is not deleted files, but stale hard-coded paths. In this post, I cover exactly how I did it.

## A Little Gotcha Before We Begin

`usermod` refuses to touch an account that is logged in or has running processes:

```
usermod: user old-user is currently used by process NNNN
```

Since this was the **only** admin account on the machine, I couldn't rename it while
logged into it. The fix is a throwaway second admin account that does the surgery while
the real account is fully logged out.

With that, here are the steps to change the identity of an existing user.

## Step 1 — Create a temporary admin

While still logged in as the old user:

```bash
sudo adduser tempadmin
sudo usermod -aG sudo tempadmin
```

## Step 2 — Log out completely and switch

This part matters: **Log Out** of GNOME — not lock, not "Switch User". The old session
must actually end. Then log in as `tempadmin` at the greeter and open a terminal.

## Step 3 — Confirm the old account is truly idle; if needed terminate the sessions

```bash
who                                   # old user should not appear
pgrep -u old-user                     # should print nothing
sudo loginctl terminate-user old-user 2>/dev/null
pgrep -u old-user || echo "clear - safe to proceed"
```
Proceed to Step 4 if the message says `clear - safe to proceed`. 

Before renaming, record the account's current numbers so you can confirm nothing shifted
afterward — and so you're not assuming mine:

```bash
id old-user        # note the uid=, gid=, and the full groups= list
```

On my machine both the UID and GID were **1000** (the first account the Ubuntu installer
creates). **Yours may differ** — on a multi-user box, a migrated system, or one with service
accounts, the first human user isn't always 1000. Whatever your values are, they should be
*identical* before and after; keeping them unchanged is exactly why we never pass `-u`.

## Step 4 — The actual rename

Three commands do the core work:

```bash
# Rename the login AND move/rename the home dir (last arg is the CURRENT name):
sudo usermod -l systemhalted -d /home/systemhalted -m old-user

# Rename the matching private group; the GID stays unchanged:
sudo groupmod -n systemhalted old-user

# Update the display/full name shown at the login screen:
sudo usermod -c "systemhalted" systemhalted
```

Why this is safe: the **UID stays unchanged, 1000 on my machine** — `usermod -l` changes the
login name and `-d -m` moves the home directory's contents, but the UID stays put because
I'm not passing `-u`. With the numeric owner unchanged, `usermod -m` *moves* the home
directory and tries to adapt ownership, permissions, ACLs, and extended attributes under the
new path — though the manpage notes some cases may still need manual fixing. In the normal
same-UID case, the intent is relocation rather than deletion, but I still treated backup as 
mandatory. The account's authentication entry is preserved through the rename, so the same 
password keeps working.

## Step 5 — Fix what usermod doesn't touch

This is where the real work hides. `usermod` renames the account, but several things keep
pointing at the old path or the old name.

**(a) Hard-coded paths.** A scan of my home turned up ~196 files under `.config`,
`.local`, and `.claude` containing the literal string `/home/old-user` — almost all
of it, in my case, JetBrains and VS Code state. Editing them in bulk is a trap:
many are binary or fragile JSON, and a stray `sed` can corrupt them. The clean, reversible 
fix is a single compatibility symlink:

```bash
sudo ln -s /home/systemhalted /home/old-user
```

Now every stale `/home/old-user/...` reference resolves transparently. No file edits,
no corruption risk. It's not entirely free, though — a lingering symlink can confuse
backups, scripts, future users, or security scans — so keep it (documented) until you're
confident nothing references the old path, then remove it.

**(b) The user crontab spool** isn't auto-renamed (the same goes for `at` jobs, if you
use them):

```bash
f=/var/spool/cron/crontabs/old-user
sudo test -f "$f" && sudo mv "$f" /var/spool/cron/crontabs/systemhalted \
  && sudo chown systemhalted:crontab /var/spool/cron/crontabs/systemhalted
```

**(c) GNOME's AccountsService** keeps per-user login-screen prefs keyed by name:

```bash
f=/var/lib/AccountsService/users/old-user
sudo test -f "$f" && sudo mv "$f" /var/lib/AccountsService/users/systemhalted
```

**(d) Claude Code session history.** Claude Code names its project folders after the
working directory. Mine were all `-home-old-user-*`, so prior session history was
keyed to the old path:

```bash
cd /home/systemhalted/.claude/projects

for d in -home-old-user*; do
  mv "./$d" "./${d/-home-old-user/-home-systemhalted}"
done
```

Two gotchas bit me here. First, the directory names start with `-`, so every tool treats
them as options — prefix paths with `./` (or use `--`) or you'll get a wall of
`invalid option -- 'h'`. Second, a `-home-systemhalted` folder already existed from a
session run *after* the home move, so the bare rename would collide. I merged that one
instead of moving it:

```bash
cp -a --update=none "./-home-old-user/." "./-home-systemhalted/" \
  && rm -rf "./-home-old-user"
```

`--update=none` means any file that already exists at the destination is left untouched —
it's never overwritten, regardless of timestamps.

## Step 6 — Verify before trusting it

```bash
getent passwd systemhalted    # home, shell, GECOS all correct
getent group  systemhalted    # same group, GID unchanged (1000 on mine)
id systemhalted               # the important one
ls -ld /home/systemhalted     # owned systemhalted:systemhalted
ls -ld /home/old-user         # symlink -> /home/systemhalted
```

The line I cared most about was `id`, confirming the renamed account was still in **both**
`sudo` and `docker` — i.e. admin and container access carried over intact.

## Step 7 — Reboot and live in it

```bash
sudo reboot
```

Log in as `systemhalted` with the old password. Terminal opens in `/home/systemhalted`,
the IDEs launch with their state, `docker ps` works, my shell tooling works, and Claude
Code shows all the prior history.

## Step 8 — Remove the temporary admin

Only after the renamed account is confirmed working:

```bash
sudo deluser --remove-home tempadmin
```

Worth knowing: if `deluser` ever runs *without* `--remove-home` (or partially), it leaves
two orphans behind — `/home/tempadmin` and `/var/lib/AccountsService/users/tempadmin` —
which you then clean up by hand:

```bash
sudo rm -rf /home/tempadmin
sudo rm /var/lib/AccountsService/users/tempadmin
```

## Rollback, just in case

Everything is reversible from the `tempadmin` session until you delete it. If anything
looked wrong, I had this ready:

```bash
sudo rm /home/old-user
sudo usermod -l old-user -d /home/old-user -m systemhalted
sudo groupmod -n old-user systemhalted
sudo usermod -c "Old User" old-user
```

## Important Notes and Observations

- **No data was lost in my case** — a same-UID rename *moves* files; it doesn't delete them by design.
- **The danger is stale paths, not lost files** — and one symlink neutralizes all of them.
- **Never bulk-`sed` IDE state** — it's binary/JSON and corrupts easily.
- **Secrets mostly survive, but check them.** GNOME Keyring is unlocked by your login
password, which didn't change, so keyring-backed secrets keep working (maybe a one-time
unlock prompt). Saved Wi-Fi depends on setup — NetworkManager profiles may be system-wide,
per-user, or keyring-backed — so verify rather than assume.
- **The compatibility symlink is practical, not free.** It saves you from editing hundreds
of files, but document it and remove it once you're sure nothing uses the old path.

The whole thing took one reboot and zero reinstalls. The account that started life as
`old-user` is now `systemhalted` as far as normal desktop and shell tooling are concerned.
(The kernel itself never cared — to it, credentials are numeric UIDs and GIDs, not names;
the login name was only ever a label on top of UID 1000.)

---

*Disclaimer: This worked on my single-admin Ubuntu/GNOME machine, and I'm sharing it as a
record of what I did — not as a guaranteed recipe for yours. Renaming a user touches login,
ownership, and system state, so treat every command here as something to understand before
you run it, not to paste blindly. Setups differ (other desktops, network/LDAP accounts,
encrypted or NFS home directories, services running as the user), and any of those can change
the outcome. **Take a backup first, keep the `tempadmin` escape hatch until you've confirmed
everything works, and proceed at your own risk.** The username here (`old-user`) is a
placeholder; the real one has been obfuscated.*
