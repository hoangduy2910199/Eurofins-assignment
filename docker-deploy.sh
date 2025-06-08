#!/bin/bash
# Script to deploy a Docker container from a specified image

image=""
container_name=""
port=""


# Function to login to Docker private registry
docker_registry_login() {
	    read -p "Enter Docker registry (e.g., registry.example.com): " REGISTRY
	        read -p "Enter username: " USERNAME
		    read -s -p "Enter password: " PASSWORD
		        image=$(read -p "Enter image name (e.g., myrepo/myimage:tag): " input && echo "${input}")
			    container_name=$(read -p "Enter container name: " input && echo "${input}")
			        port=$(read -p "Enter port to expose (default 8080): " input && echo "${input}")
				    echo
				        echo "$PASSWORD" | docker login $REGISTRY -u $USERNAME --password-stdin
				}



				# Uncomment the following line to enable Docker registry login
				# docker_registry_login
				docker_deploy_container() {


					    if [[ -z "$image" || -z "$container_name" || -z "$port" ]]; then
						            echo "Error: image name, container name, and port must be provided."
							            exit 1
								        fi

									    # Pull the latest image
									        echo "Pulling Docker image: $image"
										    docker pull $image

										        # Stop and remove existing container if it exists
											    if [ "$(docker ps -aq -f name=$container_name)" ]; then
												            echo "Stopping and removing existing container: $container_name"
													            docker stop $container_name
														            docker rm $container_name
															        fi

																    # Run the new container
																        echo "Starting new container: $container_name"
																	    docker run -d --rm --name $container_name -p $port:80 $image

																	        echo "Deployment complete. Container '$container_name' is running on port $port."
																	}

																docker_registry_login
															docker_deploy_container
