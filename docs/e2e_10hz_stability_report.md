# E2E 10Hz Stability Report

Date: 2026-05-17

Goal:

- Make the ShadowMode E2E camera-to-GUI path stable at 10Hz.
- Keep each change measurable and reversible.

Reporting:

- Short progress notes are posted in the active Codex chat.
- This file keeps the running report for later review.

## Working Hypothesis

The LEAD/E2E model path is fast enough for 10Hz. The likely bottlenecks are camera
publication, ROS image delivery, overlay generation, GUI subscription/paint timing,
and GPU contention from optional perception nodes.

## Log

### Initial Setup

- Created this live report file.
- Next step: inspect current running ROS processes and measure topic rates/latency.
