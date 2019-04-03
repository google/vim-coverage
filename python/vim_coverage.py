# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Python-only helpers for vim-coverage."""

import os, os.path
import coverage


def GetCoveragePyLines(path, source_file):
  """Get (covered, uncovered) lines for source_file from .coverage file at path.
  """
  prev_cwd = os.getcwd()
  source_file = os.path.abspath(source_file)
  try:
    os.chdir(os.path.isfile(path) and os.path.dirname(path) or path)
    try:
      # Coverage.py 4.0 and higher.
      cov = coverage.Coverage()
    except AttributeError:
      cov = coverage.coverage()
    cov.load()
  finally:
    os.chdir(prev_cwd)
  try:
    data = cov.get_data()
  except AttributeError:
    # Coverage.py before 5.
    data = cov.data
  try:
    # Coverage.py 4.0 and higher.
    covered_lines = data.lines(source_file)
  except TypeError:
    covered_lines = data.line_data()[source_file]
  uncovered_lines = cov.analysis(source_file)[2]
  return (covered_lines or [], uncovered_lines)
