<!-- .github/pull_request_template.md (platform-infra) -->
## What and why

## How it was tested

## Checklist
- [ ] `terraform fmt`, `validate` and `tflint` pass locally
- [ ] I read every plan comment the pipeline posted, and nothing is destroyed by surprise
- [ ] Changes go to dev first; staging (and prod) follow in a later PR when it's risky
- [ ] No secrets, keys or personal data in the diff
