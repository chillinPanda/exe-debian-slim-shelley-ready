# Project guidance

- Write project documentation, code comments, and commit messages in English.
- Optimize used VM filesystem space while preserving a working Shelley browser.
- Keep `exe.dev/install-shelley="true"`: exe.dev installs Shelley at VM creation
  and uses the label to recognize agent support in its dashboard.
- Do not bake a Shelley binary or credentials into the image.
- Maintain one supported image configuration. Archive experiments outside the source tree.
- Keep one pinned browser bundle. Preserve the RAM-cache launcher and browser resources.
- Keep the Debian-sourced Git package tracked by dpkg; preserve source/license metadata.
- Include build/git-minimal.sh in corresponding-source exports.
- Keep upstream attribution and bundled package licenses intact.
- Run the image build, `scripts/smoke-test.sh`, and `scripts/measure.sh` after
  image changes. Check shell scripts with ShellCheck.
- Distinguish local Docker checks from verification on a real exe.dev VM.
- Do not publish images or push commits unless the user requests it.
