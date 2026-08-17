# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## dashboard/

Ingress-only component: routes `dashboard.local` to the `kubernetes-dashboard` Service (port 80) in the `kubernetes-dashboard` namespace. Assumes the Kubernetes Dashboard itself is already installed in that namespace — this directory does not deploy it. Requires an Ingress controller on the cluster and a hosts-file entry mapping `dashboard.local` to the cluster's ingress IP.
