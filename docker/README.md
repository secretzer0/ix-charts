# TrueNAS Dragonfish Validation Tools Docker Image

This Docker image contains the validation tools needed for maintaining the TrueNAS Dragonfish (24.04) charts repository.

## Purpose

Since the original iX Systems validation tools are tightly coupled with their repository structure (expecting 'master' branch), we need our own Docker image that:
- Works with the 'main' branch as default
- Provides stability for long-term maintenance
- Ensures independence from upstream changes

## Building the Image

```bash
cd docker
./build.sh
```

## Testing Locally

After building, you can test the image:

```bash
# Run health check
docker run --rm secretzer0/truenas-dragonfish-validation:latest

# Test catalog validation
docker run --rm -v $(pwd)/..:/data secretzer0/truenas-dragonfish-validation:latest \
    catalog_validate validate --path /data

# Test dev charts validation
docker run --rm -v $(pwd)/..:/data secretzer0/truenas-dragonfish-validation:latest \
    dev_charts_validate validate --path /data
```

## Publishing to Docker Hub

1. Create a Docker Hub account if you don't have one: https://hub.docker.com/
2. Login to Docker Hub:
   ```bash
   docker login
   ```
3. Push the image:
   ```bash
   docker push secretzer0/truenas-dragonfish-validation:1.0.0
   docker push secretzer0/truenas-dragonfish-validation:latest
   ```

## Alternative: GitHub Container Registry

If you prefer to use GitHub Container Registry (ghcr.io):

1. Login to GitHub Container Registry:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u secretzer0 --password-stdin
   ```

2. Tag and push:
   ```bash
   docker tag secretzer0/truenas-dragonfish-validation:latest ghcr.io/secretzer0/truenas-dragonfish-validation:latest
   docker push ghcr.io/secretzer0/truenas-dragonfish-validation:latest
   ```

## Updating GitHub Workflows

Once the image is published, update the workflows to use it:

### .github/workflows/format_validation.yml
```yaml
container:
  image: secretzer0/truenas-dragonfish-validation:latest
```

### .github/workflows/dev_apps_validate.yml
```yaml
container:
  image: secretzer0/truenas-dragonfish-validation:latest
```

## Maintenance

When updates are needed:
1. Update the Dockerfile
2. Increment the VERSION in build.sh
3. Build and test locally
4. Push new version to registry
5. Update workflows if needed

## Tools Included

- `catalog_validate` - Validates the catalog structure and format
- `dev_charts_validate` - Validates development charts in library/ix-dev
- Python 3.11 runtime
- Git for repository operations

## Environment Variables

- `DEFAULT_BRANCH=main` - Sets the default branch for validation tools
- `PYTHONUNBUFFERED=1` - Ensures proper output in containers

## Support

For issues or questions about this Docker image, please open an issue in the ix-charts repository.