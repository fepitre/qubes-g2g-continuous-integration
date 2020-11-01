import gitlab


class GitlabCli:
    def __init__(self, url, token):
        self.token = token
        self.gl = gitlab.Gitlab(url=url, private_token=token)

    def get_runner(self, name):
        runners = self.gl.runners.list()
        for runner in runners:
            if runner.name == name:
                return runner

    def get_project(self, name):
        projects = self.gl.projects.list(search=name)
        # in case of common name acting as suffix like 'qubes-builder'
        # it will return 'qubes-builder*' matching repository names
        for project in projects:
            if project.name == name:
                return project

    def remove_project(self, name):
        project = self.get_project(name)
        self.gl.projects.delete(project.id)

    def create_project(self, name, options=None):
        project = {
            "name": name
        }
        if options:
            project.update(options)

        return self.gl.projects.create(project)

    def create_pipeline(self, project_name, options=None):
        pipeline = {
            'ref': 'master'
        }
        if options:
            pipeline.update(options)
        return self.get_project(project_name).pipelines.create(pipeline)

    def get_pipeline(self, project_name, ref):
        project = self.get_project(project_name)
        if project:
            for pipeline in project.pipelines.list():
                if pipeline.ref == ref:
                    return pipeline
