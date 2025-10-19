# Necesse Game Server Example for Agones

Dedicated [Necesse](https://necessegame.com/) Game Server hosting on Kubernetes using [Agones](https://agones.dev/site/). 

This example wraps the Necesse server with a [Go](https://golang.org) binary, and introspects
stdout to provide the event hooks for the SDK integration. The wrapper is from [Xonotic Example](https://github.com/googleforgames/agones/blob/main/examples/xonotic/main.go) with a few changes to look for the Necesse ready output message.

It is not a direct integration, but is an approach for to integrate with existing
dedicated game servers.

You will need to download the Necesse client separately to play.
