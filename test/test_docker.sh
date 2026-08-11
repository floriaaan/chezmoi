## --- Tests: docker.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/docker.sh"

test_docker_aliases_defined() {
    assert_match "docker ps" "$(alias dps)" "dps = docker ps"
    assert_match "docker exec -it" "$(alias dex)" "dex = docker exec -it"
    assert_match "docker logs -f" "$(alias dlog)" "dlog = docker logs -f"
    assert_match "docker compose up -d" "$(alias dcu)" "dcu = docker compose up -d"
    assert_match "docker compose down" "$(alias dcd)" "dcd = docker compose down"
    assert_match "docker system prune -f" "$(alias dprune)" "dprune = docker system prune -f"
}
