# Automated Project Bootstrapping & Process Management

Automated deployment and process management system (deploy_agent.sh) for the Student Attendance Tracker Python application (r.kayumba@alustudent.com).

## Features & Usage
Run the master script interactively:
./deploy_agent.sh

- Feature 1: Deploy application (pre-flight checks, directory creation, roster setup, permissions, and threshold updates).
- Feature 2: Run application standalone.
- Feature 3: Archive logs with timestamped filenames.
- Signal Handling: Traps Ctrl+C and Ctrl+Z during deployment to package incomplete instances into a .zip archive.
