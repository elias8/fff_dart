# FFF Dart benchmarks

Run every workload and print one report:

```sh
dart run benchmark/benchmark.dart
```

Run selected workloads or change the number of measured calls:

```sh
dart run benchmark/benchmark.dart --only file-search,grep --iterations 500
```

Available workloads are `index`, `file-search`, `directory-search`,
`mixed-search`, `glob`, `grep`, and `multi-grep`. Each workload creates its
own deterministic temporary fixture and runs in a separate Dart process. The
report includes median latency, nearest-rank P95, and the RSS change during
measured calls. It uses three warmups; fixture creation and initial scans are
outside the timed calls. RSS includes Dart and native allocator retention, so
it is an observation rather than a leak measurement.
