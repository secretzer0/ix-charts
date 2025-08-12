# TrueNAS Dragonfish Ecosystem Fork Strategy

## Overview

To ensure complete independence and long-term stability for TrueNAS Dragonfish 24.04 maintenance, we should fork and maintain our own versions of all critical dependencies.

## Repositories to Fork

### 1. catalog_validation (CRITICAL)
- **Original**: https://github.com/truenas/catalog_validation
- **Fork to**: https://github.com/secretzer0/catalog_validation
- **Purpose**: Validates chart structure and catalog format
- **Used by**: GitHub Actions workflows, local development
- **Modifications needed**:
  - Update default branch references from 'master' to 'main'
  - Pin dependencies for stability
  - Add Dragonfish-specific validation rules if needed

### 2. catalog_update (IMPORTANT)
- **Original**: https://github.com/truenas/catalog_update
- **Fork to**: https://github.com/secretzer0/catalog_update
- **Purpose**: Automatically updates app versions when new Docker images are released
- **Used by**: Automated dependency updates
- **Modifications needed**:
  - Configure for our repository structure
  - Update branch references
  - Customize update policies for Dragonfish stability

### 3. containers (OPTIONAL)
- **Original**: https://github.com/truenas/containers
- **Fork to**: https://github.com/secretzer0/truenas-containers
- **Purpose**: Custom Docker containers for specific TrueNAS apps (tftpd-hpa, rsyncd)
- **Used by**: Specific apps that require custom containers
- **Current usage**: tftpd-hpa, rsyncd apps use ixsystems/tftpd-hpa and ixsystems/rsyncd images

## Fork Setup Instructions

### Step 1: Fork Repositories on GitHub

1. Go to each repository listed above
2. Click "Fork" button
3. Fork to your account (secretzer0)
4. Clone locally for modifications

### Step 2: catalog_validation Fork Setup

```bash
# Clone the fork
git clone git@github.com:secretzer0/catalog_validation.git
cd catalog_validation

# Create main branch from master
git checkout -b main
git push -u origin main

# Set main as default branch on GitHub
# (Do this in GitHub Settings → Branches)

# Update code to use main branch
find . -type f -exec grep -l "master" {} \; | xargs sed -i 's/master/main/g'

# Commit changes
git add -A
git commit -m "Update default branch to main for Dragonfish maintenance"
git push
```

### Step 3: catalog_update Fork Setup

```bash
# Clone the fork
git clone git@github.com:secretzer0/catalog_update.git
cd catalog_update

# Create main branch from master
git checkout -b main
git push -u origin main

# Update configuration for our repository
# Edit configuration files to point to secretzer0/ix-charts

# Commit changes
git add -A
git commit -m "Configure for Dragonfish charts maintenance"
git push
```

### Step 4: Update Docker Image

Update our Docker image to use forked repositories:

```dockerfile
# In docker/Dockerfile, replace:
RUN git clone https://github.com/truenas/catalog_validation.git /app/catalog_validation

# With:
RUN git clone https://github.com/secretzer0/catalog_validation.git /app/catalog_validation
```

## Integration Plan

### Phase 1: Fork and Configure (Immediate)
1. Fork catalog_validation repository
2. Update to use 'main' branch
3. Build new Docker image using fork
4. Test thoroughly

### Phase 2: Extend Functionality (Short-term)
1. Fork catalog_update repository
2. Configure for our maintenance needs
3. Set up automated updates with conservative policies
4. Integrate with our CI/CD pipeline

### Phase 3: Custom Containers (As Needed)
1. Fork containers repository if we need custom app containers
2. Build and maintain our own container images
3. Update affected charts to use our containers

## Benefits of Forking

1. **Complete Independence**: Not affected by upstream breaking changes
2. **Stability Guarantee**: Control over all updates and changes
3. **Custom Features**: Add Dragonfish-specific functionality as needed
4. **Version Control**: Maintain compatibility with Dragonfish 24.04
5. **Security**: Apply security patches on our schedule
6. **Long-term Support**: Maintain as long as needed for Dragonfish users

## Maintenance Strategy

### Regular Maintenance
- Monitor upstream for security fixes
- Backport relevant improvements
- Maintain compatibility with Dragonfish

### Version Policy
- Use semantic versioning for our forks
- Tag stable releases for production use
- Maintain changelog for all modifications

### Documentation
- Document all changes from upstream
- Maintain compatibility matrix
- Provide migration guides if needed

## Docker Hub / GitHub Container Registry Setup

### For Validation Tools
```bash
# Build with our forks
docker build -t secretzer0/dragonfish-validation:1.0.0 .
docker push secretzer0/dragonfish-validation:1.0.0
```

### For App Containers (if needed)
```bash
# Example for custom rsyncd
docker build -t secretzer0/rsyncd:dragonfish .
docker push secretzer0/rsyncd:dragonfish
```

## GitHub Actions Updates

Once forks are ready, update workflows:

```yaml
# Use our custom validation image
container:
  image: secretzer0/dragonfish-validation:latest

# Or use GitHub Container Registry
container:
  image: ghcr.io/secretzer0/dragonfish-validation:latest
```

## Timeline

1. **Week 1**: Fork and configure catalog_validation
2. **Week 2**: Build and test custom Docker image
3. **Week 3**: Fork and configure catalog_update
4. **Week 4**: Full integration testing
5. **Ongoing**: Monitor and maintain forks

## Notes

- Start with catalog_validation as it's most critical
- Test thoroughly before switching production workflows
- Keep detailed documentation of all changes
- Consider setting up automated sync for non-breaking upstream changes
- Maintain good relationship with upstream for security notifications

## Commands Summary

```bash
# Fork repositories on GitHub first, then:

# Setup catalog_validation fork
git clone git@github.com:secretzer0/catalog_validation.git
cd catalog_validation
git checkout -b main
git push -u origin main
# Make necessary code changes
git commit -am "Configure for Dragonfish maintenance"
git push

# Setup catalog_update fork
git clone git@github.com:secretzer0/catalog_update.git
cd catalog_update
git checkout -b main
git push -u origin main
# Make necessary code changes
git commit -am "Configure for Dragonfish charts"
git push

# Build new Docker image
cd ix-charts/docker
# Update Dockerfile to use forks
./build.sh

# Push to registry
docker push secretzer0/dragonfish-validation:latest
```