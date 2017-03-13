package pcf_pipelines_test

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	yaml "gopkg.in/yaml.v2"

	"github.com/concourse/atc"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var placeholderRegexp = regexp.MustCompile("{{([a-zA-Z0-9-_]+)}}")

var _ = Describe("pcf-pipelines", func() {
	cwd, err := os.Getwd()
	if err != nil {
		log.Fatalf("failed to get working dir: %s", err)
	}

	baseDir := filepath.Base(cwd)

	var pipelinePaths []string
	err = filepath.Walk(cwd, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if filepath.Base(path) == "pipeline.yml" {
			relPipelinePath, err := filepath.Rel(cwd, path)
			if err != nil {
				return err
			}
			pipelinePaths = append(pipelinePaths, relPipelinePath)
		}

		return nil
	})
	if err != nil {
		log.Fatalf("failed to walk: %s", err)
	}

	for _, path := range pipelinePaths {
		pipelinePath := path

		Context(fmt.Sprintf("pipeline at %s", pipelinePath), func() {
			var configBytes []byte

			BeforeEach(func() {
				var readErr error
				configBytes, readErr = ioutil.ReadFile(pipelinePath)
				Expect(readErr).NotTo(HaveOccurred())
			})

			It("specifies all and only the params that the pipeline's tasks expect", func() {
				cleanConfigBytes := placeholderRegexp.ReplaceAll(configBytes, []byte("true"))

				var config atc.Config
				err = yaml.Unmarshal(cleanConfigBytes, &config)
				Expect(err).NotTo(HaveOccurred())

				for _, job := range config.Jobs {
					for _, task := range allTasksInPlan(&job.Plan, []atc.PlanConfig{}) {
						failMessage := fmt.Sprintf("Found error in the following pipeline:\n    %s\n\nin the following task's params:\n    %s/%s\n", pipelinePath, job.Name, task.Name())

						var configParams []string
						for k := range task.Params {
							configParams = append(configParams, k)
						}

						if strings.HasPrefix(task.TaskConfigPath, baseDir) {
							taskPath := strings.TrimPrefix(task.TaskConfigPath, baseDir+"/")
							relpath, err := filepath.Rel(cwd, filepath.Join(cwd, taskPath))
							Expect(err).NotTo(HaveOccurred())

							bs, err := ioutil.ReadFile(relpath)
							Expect(err).NotTo(HaveOccurred())

							taskConfig := atc.TaskConfig{}
							err = yaml.Unmarshal(bs, &taskConfig)
							Expect(err).NotTo(HaveOccurred())

							var taskParams []string
							for k := range taskConfig.Params {
								taskParams = append(taskParams, k)
							}

							assertUnorderedEqual(taskParams, configParams, failMessage)
						}
					}
				}
			})

			It("has a params file with all and only the params that the pipeline specifies", func() {
				paramsPath := filepath.Join(filepath.Dir(pipelinePath), "params.yml")
				_, err := os.Lstat(paramsPath)
				Expect(err).NotTo(HaveOccurred())

				bs, err := ioutil.ReadFile(paramsPath)
				Expect(err).NotTo(HaveOccurred())

				paramsMap := map[string]interface{}{}
				err = yaml.Unmarshal(bs, paramsMap)
				Expect(err).NotTo(HaveOccurred())

				var params []string
				for k := range paramsMap {
					params = append(params, k)
				}

				matches := placeholderRegexp.FindAllStringSubmatch(string(configBytes), -1)

				uniqueMatches := map[string]struct{}{}
				for _, match := range matches {
					uniqueMatches[match[1]] = struct{}{}
				}

				var placeholders []string
				for match := range uniqueMatches {
					placeholders = append(placeholders, match)
				}

				failMessage := fmt.Sprintf(`
Found error with the following pipeline:
%s

in the following params template:
%s
`, pipelinePath, paramsPath)

				assertUnorderedEqual(placeholders, params, failMessage)
			})
		})
	}
})

func allTasksInPlan(seq *atc.PlanSequence, tasks []atc.PlanConfig) []atc.PlanConfig {
	for _, planConfig := range *seq {
		if planConfig.Aggregate != nil {
			tasks = append(tasks, allTasksInPlan(planConfig.Aggregate, tasks)...)
		}
		if planConfig.Do != nil {
			tasks = append(tasks, allTasksInPlan(planConfig.Do, tasks)...)
		}
		if planConfig.Task != "" {
			tasks = append(tasks, planConfig)
		}
	}

	return tasks
}

func taskConfigsForJob(job atc.JobConfig) []atc.PlanConfig {
	tasks := []atc.PlanConfig{}

	for _, planConfig := range job.Plan {
		if planConfig.Task != "" {
			tasks = append(tasks, planConfig)
		}
	}

	return tasks
}

func assertUnorderedEqual(left, right []string, failMessage string) {
	for _, l := range left {
		Expect(right).To(ContainElement(l), failMessage)
	}

	for _, r := range right {
		var found bool

		for _, l := range left {
			if r == l {
				found = true
				break
			}
		}

		if !found {
			Expect(right).NotTo(ContainElement(r), failMessage)
		}
	}
}
