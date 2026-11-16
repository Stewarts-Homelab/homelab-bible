# Example: verify a local media mount before writing

The helper applies to a local filesystem with a readable UUID. Use the expected UUID from a known inventory, which is stronger evidence than reading an unexpected mount and trusting its current value. Do not use an unverified UUID from the target itself as the baseline.

```bash
./scripts/check-storage-mount.sh /mnt/example-media '<expected-filesystem-uuid>'
```

Run in the same mount namespace as the intended check. Bash, util-linux findmnt and access to mount/device metadata are required. Ordinarily start without elevation. A missing or unreadable UUID cannot pass. Two cloned filesystems may share a UUID, so compare physical identity separately when relevant. A matching UUID does not prove service permissions, bind subtree identity or network-share health. For a bind mount inspect its source and subtree separately. Use [storage diagnostics](../docs/operations/storage-diagnostics.md) for other sources.

| Exit | Meaning and next step |
| --- | --- |
| 0 | Exact target and expected UUID match. Verify the app mapping before startup. |
| 1 | No exact mount verified. Check namespace and findmnt stderr. |
| 2 | Missing or ambiguous UUID. Investigate source and device visibility. |
| 3 | UUID mismatch. Compare against the known inventory. |
| 64 / 69 | Invalid invocation / missing findmnt. Correct the test prerequisites. |

This helper never mounts, repairs, deletes or restarts. It requires no rollback.
