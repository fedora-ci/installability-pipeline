#!groovy

@Library('fedora-pipeline-library@candidate') _

import groovy.json.JsonBuilder

def pipelineMetadata = [
    pipelineName: 'installability',
    pipelineDescription: 'Test whether RPM packages can be installed, upgraded, downgraded and removed.',
    testCategory: 'functional',
    testType: 'installability',
    maintainer: 'Fedora CI',
    docs: 'https://github.com/fedora-ci/installability-pipeline',
    contact: [
        irc: '#fedora-ci',
        email: 'ci@lists.fedoraproject.org'
    ],
]
def artifactId
def additionalArtifactIds
def testingFarmRequestId
def testingFarmResult
def xunit


pipeline {

    agent { label 'master' }

    options {
        buildDiscarder(logRotator(daysToKeepStr: '180', artifactNumToKeepStr: '100'))
        timeout(time: 8, unit: 'HOURS')
    }

    parameters {
        string(name: 'ARTIFACT_ID', defaultValue: '', trim: true, description: '"koji-build:&lt;taskId&gt;" for Koji builds; Example: koji-build:46436038')
        string(name: 'ADDITIONAL_ARTIFACT_IDS', defaultValue: '', trim: true, description: 'A comma-separated list of additional ARTIFACT_IDs')
    }

    environment {
        TESTING_FARM_API_KEY = credentials('testing-farm-api-key')
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    artifactId = params.ARTIFACT_ID
                    additionalArtifactIds = params.ADDITIONAL_ARTIFACT_IDS
                    setBuildNameFromArtifactId(artifactId: artifactId)

                    if (!artifactId) {
                        abort('ARTIFACT_ID is missing')
                    }
                }
                sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
            }
        }

        stage('Schedule Test') {
            steps {
                sendMessage(type: 'queued', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
                script {
                    def requestPayload = """
                        {
                            "api_key": "${env.TESTING_FARM_API_KEY}",
                            "test": {
                                "fmf": {
                                    "url": "${getGitUrl()}",
                                    "ref": "${getGitRef()}"
                                }
                            },
                            "environments": [
                                {
                                    "arch": "x86_64",
                                    "os": {
                                        "compose": "Fedora-Rawhide"
                                    },
                                    "variables": {
                                        "RELEASE_ID": "${getReleaseIdFromBranch()}",
                                        "TASK_ID": "${getIdFromArtifactId(artifactId: artifactId)}",
                                        "ADDITIONAL_TASK_IDS": "${getIdFromArtifactId(additionalArtifactIds: additionalArtifactIds, separator: ' ')}"
                                    }
                                }
                            ]
                        }
                    """
                    echo "${requestPayload}"
                    def response = submitTestingFarmRequest(payload: requestPayload)
                    testingFarmRequestId = response['id']
                }
                sendMessage(type: 'running', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
            }
        }

        stage('Wait for Test Results') {
            steps {
                script {
                    testingFarmResult = waitForTestingFarmResults(requestId: testingFarmRequestId, timeout: 60)
                    xunit = testingFarmResult.get('result', [:])?.get('xunit', '') ?: ''
                    evaluateTestingFarmResults(testingFarmResult)
                }
            }
        }
    }

    post {
        always {
            // Show XUnit results in Jenkins, if available
            script {
                if (xunit) {
                    node('pipeline-library') {
                        writeFile file: 'tfxunit.xml', text: "${xunit}"
                        sh script: "tfxunit2junit --docs-url ${pipelineMetadata['docs']} tfxunit.xml > xunit.xml"
                        junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'xunit.xml')
                    }
                }
            }
        }
        success {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, xunit: xunit, dryRun: isPullRequest())
        }
        failure {
            sendMessage(type: 'error', artifactId: artifactId, pipelineMetadata: pipelineMetadata, dryRun: isPullRequest())
        }
        unstable {
            sendMessage(type: 'complete', artifactId: artifactId, pipelineMetadata: pipelineMetadata, xunit: xunit, dryRun: isPullRequest())
        }
    }
}
