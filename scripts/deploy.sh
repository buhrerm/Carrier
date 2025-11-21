#!/bin/bash
# GitHub Webhook Auto-deployment Script
# Deploys docker-compose applications from GitHub

set -e

APPS_DIR="/opt/carrier/apps"
REPO_NAME="${1}"
BRANCH="${2}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

main() {
    log "Deployment triggered for ${REPO_NAME} (${BRANCH})"

    # Only deploy from main branch
    if [[ "${BRANCH}" != "refs/heads/main" ]]; then
        log "Skipping deployment - not main branch"
        exit 0
    fi

    # Prepare app directory
    APP_DIR="${APPS_DIR}/${REPO_NAME}"
    mkdir -p "${APP_DIR}"
    cd "${APP_DIR}"

    # Clone or update repository
    if [[ -d ".git" ]]; then
        log "Updating existing repository"
        git fetch origin
        git reset --hard origin/main
    else
        log "Cloning repository"
        # Assumes public repo or SSH key configured
        git clone "https://github.com/${GITHUB_ORG}/${REPO_NAME}.git" .
    fi

    # Check for docker-compose.yml
    if [[ ! -f "docker-compose.yml" ]]; then
        log "ERROR: No docker-compose.yml found"
        exit 1
    fi

    # Load environment if exists
    if [[ -f ".env.production" ]]; then
        cp .env.production .env
    elif [[ -f ".env.example" ]]; then
        log "WARNING: Using .env.example - configure production values!"
        cp .env.example .env
    fi

    # Deploy with docker-compose
    log "Deploying application"
    docker compose pull
    docker compose up -d --remove-orphans

    # Clean up old images
    docker image prune -f

    log "Deployment completed successfully"
}

main "$@"