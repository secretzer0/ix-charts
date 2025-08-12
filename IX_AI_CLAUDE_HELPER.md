# IX_AI_CLAUDE_HELPER.md

## Repository Overview

This is the TrueNAS SCALE charts catalog repository for TrueNAS Dragonfish (24.04), actively maintained for users who need to stay on this stable version. It contains Helm charts specifically enhanced for TrueNAS SCALE with additional UI integration features.

**Purpose**: This repository serves TrueNAS Dragonfish (24.04) users who require stability and continuity. While iX Systems has moved development to a new repository for Electric Eel (24.10+), this repository continues to be maintained for the Dragonfish user base.

## Repository Structure

### Core Directories

1. **`/charts/`** - Production-ready charts deployed to users
   - Each app has multiple version directories (e.g., `plex/1.7.60/`, `plex/2.0.19/`)
   - Version 2.x.x typically represents newer implementations with updated patterns

2. **`/community/`** - Community-contributed charts with less official support
   - Similar structure to `/charts/` but maintained by community

3. **`/library/`** - Shared libraries and development templates
   - `common/` - Common Helm chart library (v1.2.9) used as dependency by all charts
   - `common-test/` - Testing harness for common library
   - `ix-dev/` - Development versions of charts (source of truth)

4. **`/test/`**, **`/enterprise/`** - Special purpose trains (limited/no UI exposure)

5. **`/docs/`** - Documentation for chart development
   - Schema documentation for questions.yaml
   - Upgrade strategies and patterns

## Chart Architecture

### TrueNAS SCALE Chart Structure

Each chart version directory contains:

```
chartname/version/
├── Chart.yaml          # Helm chart metadata + TrueNAS dependencies
├── Chart.lock          # Dependency lock file
├── README.md           # Developer documentation
├── app-readme.md       # User-facing description for TrueNAS UI
├── questions.yaml      # TrueNAS UI form configuration
├── ix_values.yaml      # Default values (renamed from values.yaml)
├── metadata.yaml       # Additional TrueNAS metadata
└── templates/          # (if exists) Kubernetes manifests templates
```

### Key Files Explained

1. **`questions.yaml`** - Defines UI forms in TrueNAS SCALE
   - Groups: Logical grouping of configuration options
   - Questions: Individual form fields with validation
   - Portals: Quick access buttons to deployed apps
   - Schema types: string, int, boolean, path, hostpath, list, dict, ipaddr, cron
   - Dynamic references: `$ref` for system-provided values (interfaces, timezones, etc.)

2. **`ix_values.yaml`** - Default Helm values specifically for TrueNAS
   - Renamed from standard `values.yaml` during build
   - Contains all default configurations

3. **`item.yaml`** - Chart metadata at app level
   - Categories for catalog organization
   - Icon URL for UI display
   - Tags and keywords

4. **`metadata.yaml`** - Additional chart version metadata
   - Application version information
   - Changelog entries
   - Dependencies

5. **Version Control Files**:
   - `to_keep_versions.md/yaml` - Specifies versions to preserve during cleanup
   - `upgrade_strategy` - Controls upgrade behavior
   - `upgrade_strategy_disable(d)` - Disables automatic upgrades
   - `upgrade_info.json` - Upgrade path information

## Development Workflow

### Chart Development Pattern

1. **Source Location**: Development happens in `/library/ix-dev/[charts|community]/`
2. **Build Process**: `create_app.sh` copies from ix-dev to versioned directories
3. **Version Management**: Each release gets its own directory
4. **Common Library**: All charts depend on `/library/common/` for shared functionality

### Build Scripts

- **`create_app.sh`** - Builds production chart from ix-dev source
  - Downloads yq for YAML processing
  - Copies from library/ix-dev to train/app/version/
  - Renames values.yaml to ix_values.yaml
  - Creates item.yaml from Chart.yaml metadata
  
- **`helm_template_common.sh`** - Tests common library templates
  - Builds dependencies
  - Runs helm template/lint
  - Validates chart structure

- **`update_common.sh`** - Updates common library version across charts

### CI/CD Pipeline

GitHub Actions workflows:
1. **`format_validation.yml`** - Validates catalog format using ixsystems/catalog_validation container
2. **`dev_apps_validate.yml`** - Validates ix-dev charts before production build

## TrueNAS-Specific Features

### iX Volumes
- Special volume type `normalize/ixVolume` - automatically managed datasets
- Rollback support during chart upgrades
- Automatic dataset creation for hostPath volumes

### Upgrade Strategies
- Automatic snapshots before upgrades
- Rollback capabilities using ZFS snapshots
- Workload annotations for controlled shutdown:
  ```yaml
  "ix.upgrade.scale.down.workload": true
  ```

### Portal System
Dynamic URL generation for app access:
- Variables: `$variable-*`, `$kubernetes-resource_*`, `$node_ip`
- Configurable protocols, hosts, ports, paths

### System References ($ref)
1. **definitions/** - System-provided options (interfaces, GPUs, etc.)
2. **normalize/** - Value transformation and validation

## Common Patterns

### Question Types & Validation

```yaml
# String with validation
- variable: hostname
  schema:
    type: string
    valid_chars: '^[a-zA-Z0-9.-]+$'
    min_length: 1
    max_length: 253

# Path selection
- variable: dataPath
  schema:
    type: hostpath  # or path for in-container paths
    required: true

# Conditional display
- variable: advancedOption
  schema:
    show_if: [["enableAdvanced", "=", true]]
```

### Storage Patterns

All charts use common patterns for:
- Configuration storage (usually small dataset)
- Data storage (main application data)
- Additional mounts (media, downloads, etc.)

### Network Configuration

Standard patterns:
- Host networking option for services requiring it
- Service types: ClusterIP, NodePort, LoadBalancer
- DNS configuration options
- Certificate management integration

## Maintenance Guidelines

### Version Management

1. Keep at least 2-3 versions per major release
2. Mark `to_keep_versions.yaml` for important versions
3. Use `upgrade_strategy_disable` for breaking changes

### Testing

1. Use `helm_template_common.sh` for template testing
2. Validate with catalog_validation tool
3. Test upgrades from previous versions
4. Verify rollback functionality

### Documentation

1. Update `app-readme.md` for user-facing changes
2. Maintain `README.md` for technical documentation
3. Add detailed comments in `questions.yaml`
4. Document breaking changes in metadata.yaml

## Important Considerations

1. **Maintenance Focus**: Actively maintained for TrueNAS Dragonfish 24.04 users
2. **Common Library**: Version 1.2.9 is stable and well-tested with Dragonfish
3. **Validation**: Always run validation before committing changes
4. **Backward Compatibility**: Preserve upgrade paths within Dragonfish versions
5. **Security**: Never expose sensitive data in configs, regularly update app versions
6. **Performance**: Consider resource limits and requests for optimal operation
7. **Persistence**: Use iX volumes for data that needs backup/rollback
8. **App Updates**: Focus on security updates and bug fixes while maintaining stability

## Useful Commands

```bash
# Build a chart from ix-dev
./create_app.sh [train] [app]

# Test common library templates
./helm_template_common.sh template

# Validate catalog format
docker run -v $(pwd):/data ixsystems/catalog_validation:latest validate --path /data

# Update common library dependency
./update_common.sh [version]
```

## Local Testing Commands for Development

### Testing Individual Components

These commands allow you to test changes locally without triggering the full CI/CD pipeline:

#### 1. Validate Entire Catalog
```bash
# Validates the complete catalog structure and format
docker run -v $(pwd):/data ghcr.io/secretzer0/catalog_validation:latest \
  catalog_validate validate --path /data
```

#### 2. Validate Development Charts
```bash
# Validates charts in library/ix-dev before building to production
docker run -v $(pwd):/data ghcr.io/secretzer0/catalog_validation:latest \
  dev_charts_validate validate --path /data --base_branch main
```

#### 3. Test Individual Chart
```bash
# Lint a specific chart version
helm lint charts/[app-name]/[version]

# Test chart installation (dry-run mode)
helm install --dry-run --debug test-release charts/[app-name]/[version]

# Template a chart to see generated manifests
helm template test-release charts/[app-name]/[version]
```

#### 4. Test Common Library
```bash
# Test common library templates with default values
./helm_template_common.sh template

# Test with specific test values file
./helm_template_common.sh -f test-values.yaml
```

#### 5. Build Chart from Development
```bash
# Build a chart from ix-dev source to production format
# Usage: ./create_app.sh [train] [app-name]
./create_app.sh charts plex
./create_app.sh community jellyfin
```

### Quick Validation Workflow

For typical development, use this sequence:

```bash
# 1. Make changes to chart in library/ix-dev/
# 2. Build the chart to production format
./create_app.sh charts myapp

# 3. Validate the built chart
helm lint charts/myapp/[version]

# 4. Test the chart installation
helm install --dry-run --debug test charts/myapp/[version]

# 5. Validate entire catalog
docker run -v $(pwd):/data ghcr.io/secretzer0/catalog_validation:latest \
  catalog_validate validate --path /data
```

## GitHub Workflows Configuration

### Workflow Files Overview

The repository includes several GitHub Actions workflows that run automatically:

1. **Always Running (on push)**:
   - `format_validation.yml` - Validates catalog format using ixsystems/catalog_validation Docker image
   - `dev_apps_validate.yml` - Validates development charts in library/ix-dev
   - `lint.yaml` - Python linting for upgrade_strategy files
   - `json_format_validation.yaml` - JSON validation for upgrade_info.json files

2. **Branch-Specific (main only)**:
   - `update_catalog.yaml` - Auto-generates and commits catalog.json and app_versions.json files

3. **Pull Request Only**:
   - `charts_tests.yaml` - Full Helm chart testing with k3s clusters
   - `common_library_tests.yaml` - Tests for the common library

### Required Configuration for Fork

**Updated Files**:
- `.github/workflows/update_catalog.yaml` - Git committer updated to secretzer0 <tmelhiser@gmail.com>
- `charts/collabora/1.2.30/ci/*.yaml` - Test domains changed from ssh.sonicaj.com to example.com

**External Dependencies**:
- Docker image: `ghcr.io/secretzer0/ix_catalog_validation:latest` (our forked validation tools)
- Forked repository: https://github.com/secretzer0/ix_catalog_validation
- GitHub Actions from marketplace (all publicly available)
- No custom secrets required (GITHUB_TOKEN is automatically provided)

**Branch Configuration**:
- Repository now uses 'main' as default branch (updated from 'master' for inclusivity)
- All workflow files updated to reference 'main' branch
- Validation tools fork also uses 'main' branch

### Running Validation Locally

```bash
# Pull our forked validation image
docker pull ghcr.io/secretzer0/ix_catalog_validation:latest

# Validate catalog format
docker run -v $(pwd):/data ghcr.io/secretzer0/ix_catalog_validation:latest \
  catalog_validate validate --path /data

# Validate development charts
docker run -v $(pwd):/data ghcr.io/secretzer0/ix_catalog_validation:latest \
  dev_charts_validate validate --path /data
```

## Maintenance Strategy

### For TrueNAS Dragonfish 24.04 Users

This repository will continue to be maintained with:
- Security updates for all applications
- Bug fixes and stability improvements
- Compatible dependency updates
- New chart additions where appropriate for Dragonfish
- Preservation of existing functionality and compatibility

### Update Priorities

1. **Security Updates**: Critical security patches for applications
2. **Bug Fixes**: Addressing reported issues and improving stability
3. **App Version Updates**: Updating application versions while maintaining compatibility
4. **Feature Additions**: Conservative addition of features that don't break existing setups
5. **New Charts**: Adding popular applications compatible with Dragonfish infrastructure