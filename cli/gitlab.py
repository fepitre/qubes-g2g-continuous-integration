import gitlab


class GitlabCli:
    def __init__(self, url, token):
        self.token = token
        self.gl = gitlab.Gitlab(url=url, private_token=token)

    def delete_branch(self, owner, name, branch_name):
        project = self.get_project(owner, name)
        for branch in project.branches.list():
            if branch.name == branch_name:
                branch.delete()

    def get_branch(self, owner, name, branch_name):
        project = self.get_project(owner, name)
        for branch in project.branches.list():
            if branch.name == branch_name:
                return branch

    def get_runner(self, name):
        runners = self.gl.runners.list()
        for runner in runners:
            # desc is referring the hostname
            if runner.description == name:
                return runner

    def add_runner(self, owner, name, runner_name):
        project = self.get_project(owner, name)
        runner = self.get_runner(runner_name)
        if project and runner:
            if runner not in project.runners.list():
                project.runners.create({'runner_id': runner.id})

    def remove_runner(self, owner, name, runner_name):
        project = self.get_project(owner, name)
        runner = self.get_runner(runner_name)
        if project and runner:
            if runner in project.runners.list():
                project.runners.delete(runner.id)

    def get_project(self, owner, name):
        projects = self.gl.projects.list(search=name)
        # in case of common name acting as suffix like 'qubes-builder'
        # it will return 'qubes-builder*' matching repository names
        for project in projects:
            if project.attributes["path_with_namespace"] == '%s/%s' % (owner, name):
                return project

    def remove_project(self, ownner, name):
        project = self.get_project(ownner, name)
        if project:
            self.gl.projects.delete(project.id)

    def create_project(self, name, group=None, options=None):
        project = {
            "name": name
        }
        if options:
            project.update(options)

        # for a group
        if group:
            group_id = self.gl.groups.list(search=group)[0].id
            project['namespace_id'] = group_id

        return self.gl.projects.create(project)

    def create_pipeline(self, ownner, name, options=None):
        pipeline = {
            'ref': 'master'
        }
        if options:
            pipeline.update(options)
        return self.get_project(ownner, name).pipelines.create(pipeline)

    def get_pipeline(self, owner, name, ref, only_finished=False):
        project = self.get_project(owner, name)
        if project:
            for pipeline in project.pipelines.list():
                if pipeline.ref == ref:
                    if only_finished and pipeline.status not in ('failed', 'success'):
                        continue
                    return pipeline
