from pathlib import Path

path = Path('tool/d1c_apply.py')
source = path.read_text()
old = """    if (progressiveRepository == null ||
        learningRepository is! OrganizationQuickCaptureRepository) {
      return null;
    }
    return V2WorkflowController(
"""
new = """    if (progressiveRepository == null ||
        learningRepository is! OrganizationQuickCaptureRepository) {
      return null;
    }
    final organizationRepository = learningRepository;
    return V2WorkflowController(
"""
if source.count(old) != 1:
    raise SystemExit(f'expected one promotion guard, got {source.count(old)}')
source = source.replace(old, new, 1)
old_call = '          return await learningRepository.quickCaptureForOrganization(\n'
new_call = '          return await organizationRepository.quickCaptureForOrganization(\n'
if source.count(old_call) != 1:
    raise SystemExit(f'expected one organization call, got {source.count(old_call)}')
source = source.replace(old_call, new_call, 1)
path.write_text(source)
