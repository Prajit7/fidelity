## 0.1.0

* Initial release.
* `FidelityGovernor`: measures frame jank against the display's real frame
  budget and steps between `high`, `medium` and `low`, with cooldown,
  warmup and anti-flapping backoff.
* `FidelityScope`, `Fidelity.of`, `FidelityBuilder`, `FidelitySwitch`.
* Ready-made `AdaptiveBlur` and `AdaptiveDecoratedBox`.
* `ceiling` for external signals (battery saver, thermal, user setting) and
  `lock` for testing.
* `FidelityDebugOverlay` pill with tap-to-lock.
