.PHONY: docker
docker: ## Install docker
	curl -fsSL https://get.docker.com -o get-docker.sh
	sh ./get-docker.sh
