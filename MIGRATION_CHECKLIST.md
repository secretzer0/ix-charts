# Migration Checklist for ix-catalog_validation

## Repository Setup for ix-catalog_validation

### GitHub Repository Configuration
- [ ] Create/verify repository at: `git@github.com:secretzer0/ix-catalog_validation.git`
- [ ] Enable GitHub Container Registry (ghcr.io) for the repository
- [ ] Set up repository secrets for Docker image publishing:
  - `GITHUB_TOKEN` (automatically available)
  - Any additional secrets needed for the build process

### Docker Image Build & Publish Workflow
The ix-catalog_validation repository needs a GitHub Actions workflow to build and publish the Docker image to `ghcr.io/secretzer0/ix-catalog_validation:latest`

Create `.github/workflows/docker-publish.yml`:
```yaml
name: Docker Build and Publish

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Dockerfile Requirements
Ensure the ix-catalog_validation repository has a Dockerfile that:
1. Installs the catalog validation tools
2. Sets up `/usr/local/bin/catalog_validate` 
3. Sets up `/usr/local/bin/catalog_update`
4. Sets up `/usr/local/bin/dev_charts_validate`
5. Includes all necessary dependencies

## ix-charts Repository Status

### ✅ Completed Updates
1. **Updated all GitHub Actions workflows** to use `ghcr.io/secretzer0/ix-catalog_validation:latest`:
   - `.github/workflows/dev_apps_validate.yml`
   - `.github/workflows/dev_apps_validate_custom.yml`
   - `.github/workflows/format_validation.yml`
   - `.github/workflows/format_validation_custom.yml`
   - `.github/workflows/update_catalog.yaml`

2. **Fixed naming consistency**: All workflows now use `ix-catalog_validation` (with hyphen)

### Workflows Using the New Image
All validation workflows are now configured to pull from:
```
ghcr.io/secretzer0/ix-catalog_validation:latest
```

## Testing Steps

1. **Build and publish the Docker image from ix-catalog_validation**:
   ```bash
   cd /path/to/ix-catalog_validation
   git add .
   git commit -m "Initial setup with Docker build workflow"
   git push origin main
   ```

2. **Verify image is published**:
   ```bash
   docker pull ghcr.io/secretzer0/ix-catalog_validation:latest
   ```

3. **Test ix-charts workflows**:
   - Push a test commit to trigger the workflows
   - Monitor GitHub Actions to ensure they can pull the new image
   - Verify catalog validation passes

## Notes
- The Docker image must be publicly accessible or the ix-charts repository needs access permissions
- Consider using semantic versioning tags in addition to `latest` for better version control
- The image name in all workflows is: `ghcr.io/secretzer0/ix-catalog_validation:latest`