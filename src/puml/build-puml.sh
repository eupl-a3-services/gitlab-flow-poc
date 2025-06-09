mkdir -p ${PWD}/opt/dist/puml
docker run -v ${PWD}/opt/dist/puml:/dist a3services/cli-java-puml-builder:0.0.0-33-gae8f6fc jar2dist