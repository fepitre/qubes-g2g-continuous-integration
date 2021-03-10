#!/usr/bin/python3
# -*- encoding: utf8 -*-
#
# The Qubes OS Project, http://www.qubes-os.org
#
# Copyright (C) 2020 Frédéric Pierret <frederic.pierret@qubes-os.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

import subprocess
import os


class Service:

    def __init__(self):
        pass

    def qrexec(self, vm, service, input_data=None):
        p = subprocess.Popen(['/usr/bin/qrexec-client-vm', vm, service],
                             stdin=subprocess.PIPE,
                             stdout=open(os.devnull, 'w'))
        p.communicate(input_data.encode())

    def handle(self, obj):
        try:
            if 'pull_request' in obj:
                if obj['action'] not in ['opened', 'synchronize']:
                    return
                repo_name = obj['pull_request']['base']['repo']['full_name']
                pr_id = obj['pull_request']['number']
                base_ref = obj['pull_request']['base']['ref']
                # set target domain in qrexec policy
                self.qrexec('dom0', 'gitlabci.G2G', '{}\n{}\n{}\n{}\n'.format(
                    'GithubPullRequest', repo_name, pr_id, base_ref))
            elif 'issue' in obj:
                if obj['action'] != 'created':
                    return
                if not obj['issue'].get('pull_request', None):
                    return
                repo_url = obj['issue']['pull_request']['url']
                user = obj['comment']['user']['login']
                comment_body = obj['comment']['body']
                # set target domain in qrexec policy
                self.qrexec('dom0', 'gitlabci.G2G', '{}\n{}\n{}\n{}\n'.format(
                    'GithubCommand', repo_url, user, comment_body))
            elif 'object_kind' in obj:
                if obj['object_kind'] == 'pipeline':
                    repo_name = obj['project']['path_with_namespace']
                    pipeline_id = obj['object_attributes']['id']
                    pipeline_ref = obj['object_attributes']['ref']
                    pipeline_status = obj['object_attributes']['status']
                    pipeline_sha = obj['object_attributes']['sha']
                    # set target domain in qrexec policy
                    self.qrexec('dom0', 'gitlabci.G2G',
                                '{}\n{}\n{}\n{}\n{}\n{}\n'.format(
                                    'GitlabPipelineStatus',
                                    repo_name,
                                    pipeline_id,
                                    pipeline_ref, pipeline_status,
                                    pipeline_sha))
        except KeyError:
            pass
