.PHONY: help init validate plan apply destroy fmt lint test clean infra-status

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Variables
TERRAFORM_DIR ?= .
TF_VARS ?= terraform.tfvars
ENVIRONMENT ?= dev

# Terraform paths
TF_PLAN_FILE := $(TERRAFORM_DIR)/.tfplan

help: ## Display this help message
	@echo "$(BLUE)==== Cosmos Infomaniak - Infrastructure Automation =====$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage: make [target]$(NC)"
	@echo ""
	@echo "$(GREEN)Terraform Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make init                    # Initialize Terraform"
	@echo "  make plan ENV=prod           # Plan infrastructure changes"
	@echo "  make apply                   # Apply infrastructure changes"
	@echo "  make destroy                 # Destroy infrastructure (use with caution)"
	@echo ""

## Initialization and Setup

init: ## Initialize Terraform working directory
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"

reinit: clean init ## Reinitialize Terraform (clean + init)
	@echo "$(GREEN)✓ Terraform reinitialized$(NC)"

upgrade: ## Upgrade Terraform providers
	@echo "$(BLUE)Upgrading Terraform providers...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) init -upgrade
	@echo "$(GREEN)✓ Providers upgraded$(NC)"

## Validation and Formatting

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) validate
	@echo "$(GREEN)✓ Terraform configuration is valid$(NC)"

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) fmt -recursive
	@echo "$(GREEN)✓ Terraform files formatted$(NC)"

fmt-check: ## Check Terraform file formatting without making changes
	@echo "$(BLUE)Checking Terraform file formatting...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) fmt -recursive -check
	@echo "$(GREEN)✓ Terraform formatting check passed$(NC)"

lint: validate fmt-check ## Run linting checks (validate + fmt-check)
	@echo "$(GREEN)✓ All linting checks passed$(NC)"

## Planning and Showing

plan: ## Plan infrastructure changes
	@echo "$(BLUE)Planning Terraform changes for environment: $(ENVIRONMENT)...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) plan -out=$(TF_PLAN_FILE) \
		$(if $(TF_VARS),-var-file=$(TF_VARS)) \
		-var="environment=$(ENVIRONMENT)"
	@echo "$(GREEN)✓ Plan saved to $(TF_PLAN_FILE)$(NC)"

plan-json: ## Generate plan in JSON format
	@echo "$(BLUE)Generating Terraform plan in JSON format...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) show -json $(TF_PLAN_FILE) > tfplan.json
	@echo "$(GREEN)✓ Plan exported to tfplan.json$(NC)"

show: ## Show current Terraform state
	@echo "$(BLUE)Showing Terraform state...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) show
	@echo "$(GREEN)✓ State displayed$(NC)"

output: ## Show Terraform outputs
	@echo "$(BLUE)Showing Terraform outputs...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) output

## Apply and Destroy

apply: ## Apply infrastructure changes
	@echo "$(RED)⚠️  WARNING: You are about to apply changes to your infrastructure!$(NC)"
	@echo "$(YELLOW)Environment: $(ENVIRONMENT)$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)Applying Terraform changes...$(NC)"; \
		terraform -chdir=$(TERRAFORM_DIR) apply $(TF_PLAN_FILE) || terraform -chdir=$(TERRAFORM_DIR) apply \
			$(if $(TF_VARS),-var-file=$(TF_VARS)) \
			-var="environment=$(ENVIRONMENT)"; \
		echo "$(GREEN)✓ Infrastructure changes applied$(NC)"; \
	else \
		echo "$(YELLOW)Apply cancelled$(NC)"; \
	fi

apply-auto: ## Apply infrastructure changes without confirmation (use with caution!)
	@echo "$(RED)⚠️  APPLYING CHANGES WITHOUT CONFIRMATION!$(NC)"
	@echo "$(YELLOW)Environment: $(ENVIRONMENT)$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) apply -auto-approve \
		$(if $(TF_VARS),-var-file=$(TF_VARS)) \
		-var="environment=$(ENVIRONMENT)"
	@echo "$(GREEN)✓ Infrastructure changes applied$(NC)"

destroy: ## Destroy infrastructure (requires confirmation)
	@echo "$(RED)⚠️  DANGER: You are about to DESTROY your infrastructure!$(NC)"
	@echo "$(YELLOW)Environment: $(ENVIRONMENT)$(NC)"
	@read -p "Type 'destroy' to confirm: " -r; \
	echo; \
	if [[ $$REPLY == "destroy" ]]; then \
		echo "$(RED)Destroying infrastructure...$(NC)"; \
		terraform -chdir=$(TERRAFORM_DIR) destroy \
			$(if $(TF_VARS),-var-file=$(TF_VARS)) \
			-var="environment=$(ENVIRONMENT)"; \
		echo "$(GREEN)✓ Infrastructure destroyed$(NC)"; \
	else \
		echo "$(YELLOW)Destroy cancelled$(NC)"; \
	fi

destroy-auto: ## Destroy infrastructure without confirmation (use with extreme caution!)
	@echo "$(RED)⚠️  DANGER: DESTROYING INFRASTRUCTURE WITHOUT CONFIRMATION!$(NC)"
	@echo "$(YELLOW)Environment: $(ENVIRONMENT)$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) destroy -auto-approve \
		$(if $(TF_VARS),-var-file=$(TF_VARS)) \
		-var="environment=$(ENVIRONMENT)"
	@echo "$(GREEN)✓ Infrastructure destroyed$(NC)"

## State Management

state-list: ## List resources in Terraform state
	@echo "$(BLUE)Listing Terraform state...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) state list

state-show: ## Show details of a specific resource (usage: make state-show RESOURCE=aws_instance.example)
	@if [ -z "$(RESOURCE)" ]; then \
		echo "$(RED)Error: RESOURCE variable not set$(NC)"; \
		echo "Usage: make state-show RESOURCE=resource_type.resource_name"; \
		exit 1; \
	fi
	@echo "$(BLUE)Showing resource: $(RESOURCE)$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) state show $(RESOURCE)

state-backup: ## Create a backup of the current state
	@echo "$(BLUE)Creating state backup...$(NC)"
	@cp $(TERRAFORM_DIR)/terraform.tfstate $(TERRAFORM_DIR)/terraform.tfstate.backup.$(shell date +%Y%m%d_%H%M%S)
	@echo "$(GREEN)✓ State backup created$(NC)"

## Analysis and Diagnostics

graph: ## Generate and display resource graph
	@echo "$(BLUE)Generating resource graph...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) graph | dot -Tsvg > tfgraph.svg
	@echo "$(GREEN)✓ Graph saved to tfgraph.svg$(NC)"

cost: ## Estimate infrastructure costs (requires Infracost)
	@echo "$(BLUE)Estimating costs with Infracost...$(NC)"
	@infracost breakdown --path $(TERRAFORM_DIR)

security: ## Run security scan (requires TFSec)
	@echo "$(BLUE)Running security scan...$(NC)"
	@tfsec $(TERRAFORM_DIR)

test: ## Run Terraform tests
	@echo "$(BLUE)Running Terraform tests...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) test

infra-status: state-list output ## Display infrastructure status (state + outputs)
	@echo "$(GREEN)✓ Infrastructure status displayed$(NC)"

## Workspace Management

workspace-list: ## List Terraform workspaces
	@echo "$(BLUE)Available workspaces:$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) workspace list

workspace-select: ## Select a workspace (usage: make workspace-select WS=staging)
	@if [ -z "$(WS)" ]; then \
		echo "$(RED)Error: WS variable not set$(NC)"; \
		echo "Usage: make workspace-select WS=workspace_name"; \
		exit 1; \
	fi
	@echo "$(BLUE)Selecting workspace: $(WS)$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) workspace select $(WS)

workspace-new: ## Create a new workspace (usage: make workspace-new WS=new_workspace)
	@if [ -z "$(WS)" ]; then \
		echo "$(RED)Error: WS variable not set$(NC)"; \
		echo "Usage: make workspace-new WS=workspace_name"; \
		exit 1; \
	fi
	@echo "$(BLUE)Creating workspace: $(WS)$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) workspace new $(WS)

## Cleanup

clean: ## Remove Terraform files and caches
	@echo "$(BLUE)Cleaning Terraform files...$(NC)"
	@rm -rf $(TERRAFORM_DIR)/.terraform
	@rm -f $(TERRAFORM_DIR)/.tfplan
	@rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	@rm -f tfplan.json tfgraph.svg
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

clean-all: clean ## Complete cleanup including state backups
	@echo "$(YELLOW)Removing all backups and local state files...$(NC)"
	@rm -f $(TERRAFORM_DIR)/terraform.tfstate*
	@echo "$(GREEN)✓ Complete cleanup done$(NC)"

## CI/CD Related

ci-plan: init validate lint plan-json ## Run all checks for CI/CD pipeline
	@echo "$(GREEN)✓ CI/CD checks passed$(NC)"

ci-apply: init validate apply ## Run init, validate, and apply for CI/CD
	@echo "$(GREEN)✓ CI/CD apply completed$(NC)"

## Documentation

docs: ## Generate documentation for Terraform modules
	@echo "$(BLUE)Generating Terraform documentation...$(NC)"
	@terraform-docs markdown $(TERRAFORM_DIR) > README_TERRAFORM.md
	@echo "$(GREEN)✓ Documentation generated in README_TERRAFORM.md$(NC)"

.PHONY: clean clean-all
