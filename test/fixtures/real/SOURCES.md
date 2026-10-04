# Real-world report excerpts

Trimmed excerpts of publicly available iOS diagnostic reports, used as parser
fixtures. Only the IPS header line and a few body keys are kept (panic text cut
to 4 KB); `crashReporterKey`, `processByPid`, `binaryImages` and memory data
were removed. Full files can be fetched with `scripts/fetch_real_samples.sh`.

| Fixture | Source |
|---|---|
| `mte-tag-fault.ips` | https://raw.githubusercontent.com/0xjohnnydev/CVE-2026-28992-IOHIDFamily-FastPathUserClient-Race-Conditions/main/panic-logs/mte-tag-fault.ips |
| `aop-panic.ips` | https://raw.githubusercontent.com/0xjohnnydev/CVE-2026-28992-IOHIDFamily-FastPathUserClient-Race-Conditions/main/panic-logs/aop-panic.ips |
| `ipad-data-abort.ips` | https://raw.githubusercontent.com/0xjohnnydev/CVE-2026-28992-IOHIDFamily-FastPathUserClient-Race-Conditions/main/panic-logs/ipad-data-abort.ips |
| `agx-panic-full.ips` | https://raw.githubusercontent.com/0xjohnnydev/AGXBarrierPanic/main/panic-full-2026-05-10-151511.0002.ips |
| `sep-panic-full.ips` | https://raw.githubusercontent.com/0xjohnnydev/SEP-Exhaustion-Kernel-Panic/main/panic-full-2026-01-13-140458.0002.ips |
| `dart-panic-full.ips` | https://raw.githubusercontent.com/Kurt-228/ios27-research/964ba05c5c6c30a4ca88c32fbbff0a9b132583a6/results/panics-key/panic-full-2026-08-13-072843.0002.ips |
| `forceReset-full-2026-08-08-012443.0002.ips` | https://raw.githubusercontent.com/Kurt-228/ios27-research/964ba05c5c6c30a4ca88c32fbbff0a9b132583a6/results/panics/forceReset-full-2026-08-08-012443.0002.ips |
| `panic-base+socd-2023-10-20-130124.000.ips` | https://raw.githubusercontent.com/danijel-tolj/objectbox_crash/115dc89470942891742c291d03883a64b1a1de16/logs/panic-base%2Bsocd-2023-10-20-130124.000.ips |
| `app-crash-legacy-109.ips` | https://raw.githubusercontent.com/doronz88/pycrashreport/634dff127fa6d4d3df948a64a3e254fe208a99dc/tests/user_mode_crash_report_ios14_non_symbolicated_abort.ips |
| `app-crash-309.ips` | https://raw.githubusercontent.com/danijel-tolj/objectbox_crash/115dc89470942891742c291d03883a64b1a1de16/logs/Runner-2023-10-20-131018.ips |
| `stacks-288.ips` | https://raw.githubusercontent.com/witchfindertr/pegasus_spyware_detection_utils_ios_aos/b97f6b9b755dbb35955cc8b0349a285b1dc26f5d/iOS_Legacy_Data_Analysis/_iPhone9,1_12.1_Wed-Nov-28-2018-12_11_42-CST/Retired/stacks%2Bbackboardd-2018-11-26-155947.ips |
