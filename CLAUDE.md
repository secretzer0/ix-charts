# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

This is the actively maintained TrueNAS SCALE charts repository for TrueNAS Dragonfish (24.04). It contains Helm charts enhanced with TrueNAS-specific UI integration features. The repository follows a specific structure where charts are developed in `/library/ix-dev/` and built into versioned releases in `/charts/` and `/community/` directories.

**Maintenance Focus**: This repository is maintained for users who need to stay on TrueNAS Dragonfish 24.04 for stability, compatibility, or organizational requirements.

## Common Development Commands

### Building and Deploying Charts
```bash
# Build a chart from ix-dev source to production
./create_app.sh [train] [app-name]
# Example: ./create_app.sh charts plex

# Test common library templates
./helm_template_common.sh template

# Run helm template with specific test values
./helm_template_common.sh -f test-values.yaml

# Update common library version across all charts
./update_common.sh [version]
```

### Validation and Testing
```bash
# Validate entire catalog format (requires Docker)
docker run -v $(pwd):/data ixsystems/catalog_validation:latest validate --path /data

# Validate development charts
docker run -v $(pwd):/data ixsystems/catalog_validation:latest dev_charts_validate validate --path /data

# Lint a specific chart
helm lint charts/[app-name]/[version]

# Test chart installation (dry-run)
helm install --dry-run --debug test-release charts/[app-name]/[version]
```

## High-Level Architecture

### Chart Development Flow
1. **Development**: Charts are developed in `/library/ix-dev/[train]/[app]/`
2. **Build**: `create_app.sh` processes ix-dev charts into versioned production charts
3. **Validation**: GitHub Actions run catalog validation on all changes
4. **Deployment**: Charts in `/charts/` and `/community/` are consumed by TrueNAS SCALE

### Key Architectural Components

#### Common Library Pattern
All charts depend on `/library/common/` (v1.2.9) which provides:
- Standardized Kubernetes resource templates
- TrueNAS-specific helpers and functions
- Consistent networking, storage, and security patterns
- Resource limit management

#### TrueNAS UI Integration
Charts integrate with TrueNAS SCALE UI through:
- `questions.yaml`: Defines dynamic forms with validation, conditional logic, and system references
- `$ref` system: Pulls system data (interfaces, GPUs, timezones) into UI dropdowns
- Portal definitions: Quick-access buttons to deployed applications
- iX Volumes: Managed ZFS datasets with snapshot/rollback support

#### Version Management Strategy
- Each chart maintains multiple versions in separate directories
- Version 1.x.x: Legacy patterns, older applications
- Version 2.x.x: Modern patterns, updated dependencies
- `to_keep_versions.yaml`: Marks versions exempt from cleanup
- `upgrade_strategy_disable`: Prevents automatic upgrades for breaking changes

### Storage Architecture
- **iX Volumes**: TrueNAS-managed datasets with automatic snapshots
- **Host Paths**: Direct mounting of host directories
- **Configuration**: Small datasets for app config
- **Data**: Large datasets for application data
- Automatic rollback support via ZFS snapshots

### Upgrade System
- Pre-upgrade snapshots of all iX volumes
- Workload annotation `"ix.upgrade.scale.down.workload": true` for controlled shutdown
- Rollback capability to any previous version
- `upgrade_info.json` tracks upgrade paths and compatibility

## Important Patterns and Conventions

### When Modifying Charts
1. Always work in `/library/ix-dev/` for source changes
2. Run `create_app.sh` to build production versions
3. Validate with catalog_validation before committing
4. Test upgrades from at least one previous version
5. Update both `README.md` (technical) and `app-readme.md` (user-facing)

### questions.yaml Schema Patterns
- Use `show_if` for conditional field display
- Leverage `$ref` for system-provided values
- Group related questions for better UX
- Always provide sensible defaults
- Include validation patterns for user inputs

### Storage Best Practices
- Use iX volumes for data requiring backup/rollback
- Separate config from data volumes
- Set appropriate permissions (568:568 for apps user)
- Consider upgrade/migration scenarios

### Network Configuration
- Default to ClusterIP for internal services
- Use NodePort for external access
- Support host networking when required
- Include DNS configuration options

## Maintenance Guidelines

### Update Philosophy
- **Security First**: Prioritize security updates for all applications
- **Stability**: Maintain compatibility with Dragonfish 24.04 infrastructure
- **Conservative Updates**: Test thoroughly before releasing new versions
- **User Impact**: Consider impact on existing installations before changes

### When Updating Charts
1. Check application's official changelog for security fixes
2. Test new versions in development environment first
3. Ensure compatibility with common library v1.2.9
4. Validate UI functionality through questions.yaml
5. Document changes clearly in metadata.yaml

## Notes

- This repository is actively maintained for TrueNAS Dragonfish 24.04 users
- Always preserve backward compatibility for upgrades within Dragonfish
- The common library (1.2.9) is stable and well-tested with Dragonfish
- GitHub Actions validate all changes automatically
- Each chart version is immutable once released
- Focus on security updates and stability over new features