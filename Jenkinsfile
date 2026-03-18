#!groovy

retry (10) {
    // load pipeline configuration into the environment
    httpRequest("${FEDORA_CI_PIPELINES_CONFIG_URL}/environment").content.split('\n').each { l ->
        l = l.trim(); if (l && !l.startsWith('#')) { env["${l.split('=')[0].trim()}"] = "${l.split('=')[1].trim()}" }
    }
}

def pipelineMetadata = [
    pipelineName: 'installability',
    pipelineDescription: 'Try to install, upgrade, downgrade and remove RPM packages.',
    testCategory: 'functional',
    testType: 'installability',
    maintainer: 'Fedora CI',
    docs: 'https://github.com/fedora-ci/mini-tps',
    contact: [
        irc: '#fedora-ci',
        email: 'ci@lists.fedoraproject.org'
    ],
]
def artifactId
def additionalArtifactIds
def testingFarmRequestId
def testingFarmResult
def config
def ignoreList
def artifactName
def pipelineRepoUrlAndRef
def hook
def runUrl


pipeline {

    agent none

    libraries {
        lib("fedora-pipeline-library@${env.PIPELINE_LIBRARY_VERSION}")
    }

    options {
        buildDiscarder(logRotator(daysToKeepStr: env.DEFAULT_DAYS_TO_KEEP_LOGS, artifactNumToKeepStr: env.DEFAULT_ARTIFACTS_TO_KEEP))
        timeout(time: env.DEFAULT_PIPELINE_TIMEOUT_MINUTES, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    parameters {
        string(name: 'ARTIFACT_ID', defaultValue: '', trim: true, description: '"koji-build:&lt;taskId&gt;" for Koji builds; Example: koji-build:46436038')
        string(name: 'ADDITIONAL_ARTIFACT_IDS', defaultValue: '', trim: true, description: 'A comma-separated list of additional ARTIFACT_IDs')
        string(name: 'TEST_PROFILE', defaultValue: env.FEDORA_CI_RAWHIDE_RELEASE_ID, trim: true, description: "A name of the test profile to use; Example: ${env.FEDORA_CI_RAWHIDE_RELEASE_ID}")
        string(name: 'BODHI_UPDATE_ID', defaultValue: '', trim: true, description: '"Bodhi updated ID; Example: FEDORA-2025-7826f19244')
        string(name: 'ARTIFACT_IDS', defaultValue: '', trim: true, description: 'A comma-separated list of all koji builds in the update; Example: koji-build:46436038')
        string(name: 'DIST_GIT_BRANCH', defaultValue: '', trim: true, description: "Dist-git branch associated with the provided BODHI_UPDATE_ID")
    }

    environment {
        TESTING_FARM_API_KEY = credentials('testing-farm-api-key')
    }

    stages {
        stage('Prepare') {
            agent {
                label pipelineMetadata.pipelineName
            }
            steps {
                script {
                    if (params.BODHI_UPDATE_ID) {
                        if (!params.BODHI_UPDATE_ID) {
                            abort('BODHI_UPDATE_ID is missing')
                        }
                        if (!params.ARTIFACT_IDS) {
                            abort('ARTIFACT_IDS is missing')
                        }
                        if (!params.DIST_GIT_BRANCH) {
                            abort('DIST_GIT_BRANCH is missing')
                        }

                        currentBuild.displayName = params.BODHI_UPDATE_ID

                        if (params.DIST_GIT_BRANCH == 'epel8'){
                            abort('Installability on epel8 is disabled')
                        }

                        checkout scm
                        config = loadConfig(profile: params.DIST_GIT_BRANCH)
                        pipelineRepoUrlAndRef = [url: "${getGitUrl()}", ref: "${getGitRef()}"]
                    } else {
                        artifactId = params.ARTIFACT_ID
                        additionalArtifactIds = params.ADDITIONAL_ARTIFACT_IDS
                        artifactName = setBuildNameFromArtifactId(artifactId: artifactId, profile: params.TEST_PROFILE)

                        checkout scm
                        config = loadConfig(profile: params.TEST_PROFILE)
                        pipelineRepoUrlAndRef = [url: "${getGitUrl()}", ref: "${getGitRef()}"]

                        // check if the package is on the ignore list
                        ignoreList = loadConfig().get('ignore_list', [])
                        if (artifactName in ignoreList) {
                            abort("${artifactName} is on the pipeline ignore list, skipping...")
                        }

                        if (!artifactId) {
                            abort('ARTIFACT_ID is missing')
                        }
                    }
                }
                sendMessage(type: 'queued', artifactId: artifactId, additionalArtifactIds: params.ARTIFACT_IDS, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
            }
        }

        stage('Schedule Test') {
            agent {
                label pipelineMetadata.pipelineName
            }
            steps {
                script {
                    def requestPayload
                    if (params.BODHI_UPDATE_ID) {
                        requestPayload = [
                            api_key: "${env.TESTING_FARM_API_KEY}",
                            test: [
                                fmf: pipelineRepoUrlAndRef
                            ],
                            environments: [
                                [
                                    arch: "x86_64",
                                    os: [ compose: "${config.compose}" ],
                                    variables: [
                                        BODHI_UPDATE_ID: params.BODHI_UPDATE_ID,
                                    ],
                                    tmt: [
                                        context: [
                                            "dist-git-branch": params.DIST_GIT_BRANCH,
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    } else {
                        requestPayload = [
                            api_key: "${env.TESTING_FARM_API_KEY}",
                            test: [
                                fmf: pipelineRepoUrlAndRef
                            ],
                            environments: [
                                [
                                    arch: "x86_64",
                                    os: [ compose: "${config.compose}" ],
                                    variables: [
                                        PROFILE_NAME: "${config.profile_name}",
                                        TASK_ID: "${getIdFromArtifactId(artifactId: artifactId)}",
                                        ADDITIONAL_TASK_IDS: "${getIdFromArtifactId(additionalArtifactIds: additionalArtifactIds, separator: ' ')}"
                                    ]
                                ]
                            ]
                        ]
                    }
                    hook = registerWebhook()
                    requestPayload['notification'] = ['webhook': [url: hook.getURL()]]

                    def response = submitTestingFarmRequest(payloadMap: requestPayload)
                    testingFarmRequestId = response['id']
                }
                sendMessage(type: 'running', artifactId: artifactId, additionalArtifactIds: params.ARTIFACT_IDS, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
            }
        }

        stage('Wait for Test Results') {
            agent none
            steps {
                script {
                    def response = waitForTestingFarm(requestId: testingFarmRequestId, hook: hook)
                    testingFarmResult = response.apiResponse
                    runUrl = "${FEDORA_CI_TESTING_FARM_ARTIFACTS_URL}/${testingFarmRequestId}"
                }
            }
        }
    }

    post {
        always {
            evaluateTestingFarmResults(testingFarmResult)
        }
        success {
            sendMessage(type: 'complete', artifactId: artifactId, additionalArtifactIds: params.ARTIFACT_IDS, pipelineMetadata: pipelineMetadata, runUrl: runUrl, dryRun: isPullRequest())
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, additionalArtifactIds: params.ARTIFACT_IDS, pipelineMetadata: pipelineMetadata, runUrl: runUrl, dryRun: isPullRequest())
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, additionalArtifactIds: params.ARTIFACT_IDS, pipelineMetadata: pipelineMetadata, runUrl: runUrl, dryRun: isPullRequest())
        }
        aborted {
            script {
                if (artifactId && !testingFarmRequestId) {
                    sendMessage(type: 'complete', artifactId: artifactId, additionalArtifactIds: params.ARTIFACT_IDS, pipelineMetadata: pipelineMetadata, isSkipped: true, note: "${env.ABORT_MESSAGE}", dryRun: isPullRequest())
                }
                if (isTimeoutAborted(timeout: env.DEFAULT_PIPELINE_TIMEOUT_MINUTES, unit: 'MINUTES')) {
                    sendMessage(type: 'error', artifactId: artifactId, additionalArtifactIds: params.ARTIFACT_IDS, errorReason: 'Timeout has been exceeded, pipeline aborted.', pipelineMetadata: pipelineMetadata, runUrl: runUrl, dryRun: isPullRequest())
                }
            }
        }
    }
}
