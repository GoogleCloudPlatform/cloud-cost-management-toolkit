# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement (CLA). You (or your employer) retain the copyright to your
contribution; this simply gives us permission to use and redistribute your
contributions as part of the project. Head over to
<https://cla.developers.google.com/> to see your current agreements on file or
to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Code Reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

## Community Guidelines

This project follows
[Google's Open Source Community Guidelines](https://opensource.google/conduct/).

## Local Development & Git Safety

To protect the project from accidental leaks of private GCP Project IDs or billing table names, we enforce a "Zero-Config" policy for committed files. 

The `workflow_settings.yaml` file in the repository root contains generic placeholders. **Please do not commit your private GCP project IDs or dataset configurations.**

If you need to run the Dataform CLI locally or want to modify `workflow_settings.yaml` with your active GCP credentials for testing:

1.  **Ignore local changes to the config**: Run this command immediately after cloning to ensure your local edits are never tracked by Git:
    ```bash
    git update-index --assume-unchanged workflow_settings.yaml
    ```
    This tells Git to ignore any local modifications to `workflow_settings.yaml`. You can safely enter your private credentials for testing without risking committing them.

2.  **Re-enable tracking (if contributing template updates)**: If you are actively working on improving the base template structure of `workflow_settings.yaml` and need to commit structural changes to Git, run:
    ```bash
    git update-index --no-assume-unchanged workflow_settings.yaml
    ```