# CI/CD Pipeline for AMS Project

This CI/CD pipeline is configured on GitLab and includes several stages for managing and publishing versions of the AMS project.

## Docker Image

The pipeline uses the Docker image `a3services/hub-gitlab-flow:${AMS_REVISION}` as the base image for executing jobs.

## Prerequisites

| env_variable               | flags   | value / description                            | usage in job  |
|:---------------------------|:--------|:-----------------------------------------------|:--------------|
| A3_REPO_GIT                | V/P/E/- | gitlab.com/<PROJECT_ROOT_GROUP>/support/a3.git | ----------    |
| AMS_DOMAIN                 | V/P/-/- | <DOMAIN>.dev                                   | All (default) |
| CI_HOME                    | V/P/E/- | /cache-volume/ci/${CI_PROJECT_PATH}            | ams-origin    |
| ? CI_GROUP_ID              | V/-/E/- | 15786414                                       | All (default) |
| ? CI_JOB_TOKEN_A3          | V/-/E/- | •••••                                          | All (default) |
| ENV_HOME                   | V/-/E/- | /cache-volume/env                              | All (default) |
| GIT_DEPTH                  | V/-/E/- | 1                                              | All (default) |
| GIT_STRATEGY               | V/-/E/- | clone                                          | All (default) |
| ? GLR_HOME                 | V/P/E/- | /cache-volume/glr                              | All (default) |
| KUBECONFIG                 | F/P/E/- | •••••                                          | All (default) |
| MVN_HOME                   | V/-/E/- | /cache-volume/mvn                              | All (default) |
| NPM_HOME                   | V/-/E/- | /cache-volume/npm/${CI_PROJECT_PATH_SLUG}      | All (default) |
| ? PACKAGE_REPO_READ_TOKEN  | V/-/E/M | •••••                                          | All (default) |
| ? PORTAINER_HOST           | V/P/E/- | •••••                                          | All (default) |
| ? PORTAINER_PASSWORD       | V/P/E/M | •••••                                          | All (default) |
| ? PORTAINER_USER           | V/P/E/- | •••••                                          | All (default) |
| ? RELEASE_DEFAUTL          | V/P/E/- | 0/default/develop                              | All (default) |
| ? RELEASE_HOME             | V/P/E/- | /cache-volume/release/${CI_PROJECT_PATH_SLUG}  | All (default) |
| ROLLOUT_DEFAULT            | V/P/E/- | 0/1.6.0/war-room                               | ams-origin    |
| ROLLOUT_HOME               | V/-/E/- | /cache-volume/rolout/${CI_PROJECT_PATH}        | ams-origin    |


## Pipeline Stages
The pipeline is divided into multiple stages:

- `prepare`: Prepares the environment and sets up necessary variables.
- `process`: Reserved for additional processing (not included in this example).
- `propagate`: Creates and publishes the Docker image based on versioning.
- `publish`: Reserved for artifact publishing.
- `probe`: Reserved for testing or verification.

## Job: `ams:origin`

- `Stage`: `prepare`
- `Task`: Runs the `ams-origin` script, which:
    - Sets environment variables and saves them to the `ams-origin.env` file.
    - Exports environment variables and the version based on Git tags or default values.
    - Uses `git describe` to fetch the version if available; otherwise, it sets a default value of `notag`.
    - Generates an SVG variable content that contains AMS information such as the name, version, build date, and other metadata.
- `Artifacts`: Saves environment variables in the `origin.env`, `ams-origin.env` file for use in subsequent pipeline steps.
- `Options`
    - `--inspect` - tbd
    - `--debug` - tbd
- `Usage`
    ```
    ams:origin:
    stage: prepare
    script:
        - ams-origin
    artifacts:
        reports:
            dotenv:
                - ams-origin.env
    tags:
        - <tag>
    ```
- `Output`
    - `AMS_NAME` - recource name
    - `AMS_REVISION` - current `git describe`
    - `AMS_DIST` - name of distribution
    - `AMS_BUILD` - timestamp of build
    - `AMS_BRANCH` - branche name
    - `AMS_TRIGGER` - run trigger
    - `AMS_RESOURCE` - determines the branch type (`UNDEFINED`, `PROTECTED`, `DEFAULT`, `JIRA`, `EXPERIMENTAL`)
- `Example output`
    ```
    +[AMS-ORIGIN-CTX]----------------------------------+
    | AMS_NAME:            clamav                      |
    | AMS_REVISION:        notag                       |
    | AMS_DIST:            notag                       |
    | AMS_BUILD:           241108-162316               |
    | AMS_BRANCH:          main                        |
    | AMS_TRIGGER:         push                        |
    | AMS_RESOURCE:        PROTECTED                   |
    +-----------------------------------------------🄰🄼🅂+
    ```

## Job: `docker-release`

- `Stage`: `propagate`
- `Task`: Runs the `docker-release` script, which:
- `Options`
    - `--inspect` - tbd
    - `--debug` - tbd
    - `--service` - tbd
- `Usage`
    ```
    docker-release:
    stage: propagate
    rules:
        - if: $CI_COMMIT_REF_PROTECTED == "true"
    script:
        - docker-release
    tags:
        - <tag>
    ```
- `Output`
    - `AMS_IMAGE_REGISTRY` - link to gitlab registry
    - `AMS_IMAGE_LAYERS` - layer count
    - `AMS_IMAGE_SIZE` - size of image
- `Example output`
    ```
    +[AMS-IMAGE-CTX]-------------------------------------------------------------------------------------+
    | AMS_IMAGE_REGISTRY:  registry.gitlab.com/a3-services-dev/core/clamav/clamav:notag                         |
    | AMS_IMAGE_LAYERS:    8                                                                             |
    | AMS_IMAGE_SIZE:      303.016 MB                                                                    |
    +-------------------------------------------------------------------------------------------------🄰🄼🅂+
    ```