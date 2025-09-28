# Tdarr Mock License Server

Mock API server that emulates api.tdarr.io endpoints for development and testing. Returns success for all license validation requests, enabling all Tdarr Pro features without requiring actual license keys.

## Purpose

- **Development**: Test pro features without connecting to real license server
- **Testing**: Validate functionality of license-gated features
- **Adoption**: Enable unmapped nodes and other pro features for increased adoption

## API Endpoints

### 1. POST /api/v2/verify-key
**Purpose**: License key verification

**Request**:
```json
{
  "tdarrKey": "any-guid-or-key"
}
```

**Response**:
```json
{
  "result": true,
  "status": 200,
  "message": "License verified (mock server)"
}
```

### 2. POST /api/v2/user-stats/update
**Purpose**: Statistics update (logged but not persisted)

**Request**:
```json
{
  "tdarrKey": "license-key",
  "serverId": "machine-id",
  "stats": { }
}
```

**Response**:
```json
{
  "result": true,
  "message": "Statistics updated (mock server)"
}
```

### 3. POST /api/v2/user-stats/push-notif
**Purpose**: Push notifications (logged but not sent)

**Request**:
```json
{
  "tdarrKey": "license-key",
  "message": "notification text"
}
```

**Response**:
```json
{
  "result": true,
  "message": "Notification sent (mock server)"
}
```

### 4. GET /api/v2/updater-config
**Purpose**: Auto-updater configuration (returns empty to disable updates)

**Response**:
```json
{
  "pkgIndex": "",
  "url": "",
  "message": "Auto-update disabled (mock server)"
}
```

### 5. GET /api/v2/download-plugins
**Purpose**: Plugin synchronization (returns empty to skip plugin download)

**Response**: Empty binary response (prevents overwriting local plugin development)

## Docker Setup

### Option 1: Standalone (Recommended)

This creates a separate Docker network that your Tdarr containers can join:

```bash
# Build and start mock server
cd mock-license-server
docker-compose up -d

# View logs
docker-compose logs -f

# Check health
curl http://localhost:3000/health
```

### Option 2: Integrated with Tdarr Docker Compose

Add to your main Tdarr docker-compose.yml:

```yaml
services:
  tdarr:
    # ... existing config ...
    environment:
      - NODE_ENV=development  # Use localhost:3000 for license API
    depends_on:
      - mock-license-server

  mock-license-server:
    build: ./mock-license-server
    container_name: tdarr-mock-license
    ports:
      - "3000:3000"
    networks:
      - default
```

## Configuration for Tdarr

### Method 1: NODE_ENV Override (Easiest)

In your Tdarr docker-compose.yml:

```yaml
services:
  tdarr:
    environment:
      - NODE_ENV=development
```

This makes Tdarr use `http://localhost:3000` instead of `https://api.tdarr.io`.

**Note**: Make sure mock server is accessible as `localhost` from Tdarr container (use same Docker network).

### Method 2: DNS Override (Advanced)

Add DNS alias to docker-compose network:

```yaml
networks:
  default:
    aliases:
      - api.tdarr.io
```

Then Tdarr will resolve `api.tdarr.io` to the mock server container.

### Method 3: Hosts File (Alternative)

Add to Tdarr container's `/etc/hosts`:

```
127.0.0.1 api.tdarr.io
```

## Testing

### 1. Verify Server Running
```bash
curl http://localhost:3000/
```

Should return server info and available endpoints.

### 2. Test License Verification
```bash
curl -X POST http://localhost:3000/api/v2/verify-key \
  -H "Content-Type: application/json" \
  -d '{"tdarrKey": "test-key-12345"}'
```

Should return:
```json
{
  "result": true,
  "status": 200,
  "message": "License verified (mock server)"
}
```

### 3. Test Stats Update
```bash
curl -X POST http://localhost:3000/api/v2/user-stats/update \
  -H "Content-Type: application/json" \
  -d '{"tdarrKey": "test", "serverId": "test", "stats": {}}'
```

### 4. Check Logs
```bash
docker logs tdarr-mock-license
```

Should show all API requests with license key prefixes.

## Enabling Pro Features in Tdarr

Once mock server is running:

1. **Start Tdarr** with `NODE_ENV=development` environment variable
2. **Enter License Key** in Tdarr UI (any value works, e.g., "dev-license-key")
3. **Enable Features** in Options tab:
   - Enable "Unmapped Nodes" setting
   - All pro features should now be available

4. **Configure Unmapped Node**:
   - In node config: `nodeType=unmapped`
   - Node will register successfully without pro license

## Advantages Over Code Modification

✅ **No Source Code Changes**: Keep original pro security logic intact
✅ **Easy Toggle**: Start/stop mock server to enable/disable features
✅ **Realistic Testing**: Tests actual license validation flow
✅ **Flexible**: Can mock different license states (expired, invalid, etc.)
✅ **Production-Ready Code**: Source code remains deployment-ready

## Development Workflow

```bash
# Start mock server
cd mock-license-server && docker-compose up -d

# Start Tdarr with development mode
cd /home/tmelhiser/tdarr
docker-compose up -d

# Watch mock server logs
docker logs -f tdarr-mock-license

# Watch Tdarr logs for license validation
docker logs -f tdarr | grep -i license
```

## Troubleshooting

### Issue: Tdarr still connecting to real api.tdarr.io

**Solution**: Verify `NODE_ENV=development` is set in Tdarr container:
```bash
docker exec tdarr env | grep NODE_ENV
```

### Issue: Mock server not reachable

**Solution**: Check Docker networking:
```bash
# Verify mock server running
docker ps | grep mock-license

# Test from Tdarr container
docker exec tdarr curl http://localhost:3000/health

# Check network connectivity
docker network inspect tdarr_default
```

### Issue: License validation still failing

**Solution**: Check mock server logs for incoming requests:
```bash
docker logs tdarr-mock-license | grep verify-key
```

If no requests appear, Tdarr isn't reaching the mock server.

## Future Enhancements

Possible additions for more sophisticated testing:

- **License Expiration**: Mock expired licenses
- **Rate Limiting**: Test license validation retry logic
- **Database**: Persist statistics for analysis
- **Admin UI**: Web interface to view requests
- **Multiple License States**: Switch between valid/invalid/expired

## Security Note

⚠️ **Development Only**: This mock server should NEVER be used in production. It bypasses all license validation and grants full pro features without verification.

For production deployments, use real license keys and connect to the official api.tdarr.io endpoints.