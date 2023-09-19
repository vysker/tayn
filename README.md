# Tayn

Docker container manager.

## Intro

This CLI utility gives you some terse, helpful commands for working with Docker containers.

It's just a pet project to learn dive deeper into zsh/shell scripting. It's terrible and has glaring issues I know about, but haven't bothered to fix.

**CAUTION: Use at your own peril.**

## Install

* Download tayn.zsh
* Add `source tayn.zsh` to `~/.zshrc`
* Test with `tayn help`

## Podman

Using podman? Add `export TAYN_DEFAULT_RUNTIME="podman"` to `~/.zshrc` *after* `source tayn.zsh`

## Usage

Start some container, e.g. `docker run -d --name postgres-example -e POSTGRES_PASSWORD=test postgres:alpine`.

Run `$ tayn p` to get a numbered list of containers:

```
> tayn p
[ 0] NAMES                     STATUS
[ 1] postgres-example          Up 2 seconds
[ 2] funny_driscoll            Exited (1) 2 minutes ago
[ 3] great_poitras             Exited (1) 2 minutes ago
```

Then `$ tayn s 1` to stop container 'postgres-example'.

Or `$ tayn r 2` to restart container 'funny_driscoll'.

Or `$ tayn e 1 bash` to start a bash session in 'postgres-example'.

## Name

Tayn as in con**tayn**er.
