#!/bin/bash
# Build script for TrueNAS Dragonfish validation tools Docker image

set -e

# Configuration
IMAGE_NAME="secretzer0/truenas-dragonfish-validation"
VERSION="1.0.0"
LATEST_TAG="${IMAGE_NAME}:latest"
VERSION_TAG="${IMAGE_NAME}:${VERSION}"

echo "Building TrueNAS Dragonfish validation tools Docker image..."
echo "Image: ${IMAGE_NAME}"
echo "Version: ${VERSION}"

# Build the Docker image
docker build -t "${LATEST_TAG}" -t "${VERSION_TAG}" .

echo ""
echo "Build complete!"
echo ""
echo "To test the image locally:"
echo "  docker run --rm ${LATEST_TAG}"
echo ""
echo "To push to Docker Hub (requires login):"
echo "  docker login"
echo "  docker push ${VERSION_TAG}"
echo "  docker push ${LATEST_TAG}"
echo ""
echo "To use in GitHub Actions, update the workflows to use:"
echo "  image: ${LATEST_TAG}"