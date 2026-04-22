#!/bin/bash

# ===========================================
# SUPABASE SCHEMA DEPLOYMENT SCRIPT
# ===========================================
# This script deploys all SQL schemas in the correct order
# Run from the project root: ./supabase/scripts/deploy_schemas.sh

set -e

echo "=========================================="
echo "Deploying PharmaLearn Supabase Schemas"
echo "=========================================="

# Configuration
SCHEMAS_DIR="./supabase/schemas"
SEED_DIR="./supabase/seed"

# Function to run SQL files in a directory
deploy_directory() {
    local dir=$1
    local name=$2
    
    if [ -d "$dir" ]; then
        echo ""
        echo "Deploying: $name"
        echo "-------------------------------------------"
        
        for file in $(ls -1 "$dir"/*.sql 2>/dev/null | sort); do
            echo "  Running: $(basename $file)"
            supabase db push --file "$file"
        done
    fi
}

# Deploy in order
deploy_directory "$SCHEMAS_DIR/00_extensions" "Extensions"
deploy_directory "$SCHEMAS_DIR/01_types" "Types & Enums"
deploy_directory "$SCHEMAS_DIR/02_core" "Core Infrastructure"
deploy_directory "$SCHEMAS_DIR/03_organization" "Organization"
deploy_directory "$SCHEMAS_DIR/04_identity" "Identity & Access"
deploy_directory "$SCHEMAS_DIR/05_documents" "Documents"
deploy_directory "$SCHEMAS_DIR/06_courses" "Courses"
deploy_directory "$SCHEMAS_DIR/07_training" "Training"
deploy_directory "$SCHEMAS_DIR/08_assessment" "Assessment"
deploy_directory "$SCHEMAS_DIR/09_compliance" "Compliance"
deploy_directory "$SCHEMAS_DIR/10_quality" "Quality"
deploy_directory "$SCHEMAS_DIR/11_audit" "Audit"
deploy_directory "$SCHEMAS_DIR/12_notifications" "Notifications"
deploy_directory "$SCHEMAS_DIR/13_analytics" "Analytics"
deploy_directory "$SCHEMAS_DIR/14_workflow" "Workflow"
deploy_directory "$SCHEMAS_DIR/15_cron" "Cron Jobs"
deploy_directory "$SCHEMAS_DIR/16_infrastructure" "Infrastructure"
deploy_directory "$SCHEMAS_DIR/17_extensions" "Extensions (SCORM, xAPI, etc.)"
deploy_directory "$SCHEMAS_DIR/99_policies" "RLS Policies"

echo ""
echo "=========================================="
echo "Schema deployment complete!"
echo "=========================================="

# Ask about seed data
read -p "Deploy seed data? (y/n): " deploy_seed
if [ "$deploy_seed" = "y" ]; then
    echo ""
    echo "Deploying seed data..."
    for file in $(ls -1 "$SEED_DIR"/*.sql 2>/dev/null | sort); do
        echo "  Running: $(basename $file)"
        supabase db push --file "$file"
    done
    echo "Seed data deployed!"
fi

echo ""
echo "Done!"
