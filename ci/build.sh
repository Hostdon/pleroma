echo "Building $1 using image tag $2"
docker build -t docker.io/akkoma/ci-base:$1 --build-arg=version=$1 --build-arg=TAG=$2 .
docker push docker.io/akkoma/ci-base:$1
