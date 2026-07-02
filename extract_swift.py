import re
import os

def extract_swift_blocks(content):
    pattern = r'```swift\n(.*?)```'
    matches = re.findall(pattern, content, re.DOTALL)
    return matches

def process_file(md_path, output_dir):
    basename = os.path.basename(md_path)
    name_without_ext = os.path.splitext(basename)[0]
    swift_filename = name_without_ext + '.swift'
    output_path = os.path.join(output_dir, swift_filename)

    with open(md_path, 'r') as f:
        content = f.read()

    blocks = extract_swift_blocks(content)
    if not blocks:
        print(f"  SKIP {basename}: no swift blocks found")
        return False

    combined = '\n\n// MARK: - Next Code Block\n\n'.join(blocks)

    with open(output_path, 'w') as f:
        f.write(combined)

    print(f"  OK   {swift_filename}: {len(blocks)} block(s)")
    return True

results_dir = '/Users/joeferrara/Developer/AI/nanoclaw_scratch/model-eval/results'
output_dir = '/Users/joeferrara/Developer/AI/nanoclaw_scratch/model-eval/swift-previews'

os.makedirs(output_dir, exist_ok=True)

files_to_process = []

# haiku-01 through haiku-06
for i in range(1, 7):
    pattern = f'haiku-0{i}-'
    for f in os.listdir(results_dir):
        if f.startswith(pattern) and f.endswith('.md'):
            files_to_process.append(f)

# sonnet-01 through sonnet-06
for i in range(1, 7):
    pattern = f'sonnet-0{i}-'
    for f in os.listdir(results_dir):
        if f.startswith(pattern) and f.endswith('.md'):
            files_to_process.append(f)

# opus-01 through opus-06
for i in range(1, 7):
    pattern = f'opus-0{i}-'
    for f in os.listdir(results_dir):
        if f.startswith(pattern) and f.endswith('.md'):
            files_to_process.append(f)

# opus-review-of-haiku-01 through opus-review-of-haiku-06 (with test name suffix)
for i in range(1, 7):
    pattern = f'opus-review-of-haiku-0{i}-'
    for f in os.listdir(results_dir):
        if f.startswith(pattern) and f.endswith('.md'):
            files_to_process.append(f)

# Also check for opus-review-of-haiku-01.md (without test name suffix)
for i in range(1, 7):
    fname = f'opus-review-of-haiku-0{i}.md'
    if os.path.exists(os.path.join(results_dir, fname)) and fname not in files_to_process:
        files_to_process.append(fname)

files_to_process = sorted(set(files_to_process))

print(f"Processing {len(files_to_process)} files:\n")
count = 0
for f in files_to_process:
    md_path = os.path.join(results_dir, f)
    if process_file(md_path, output_dir):
        count += 1

print(f"\nDone: {count} .swift files written to {output_dir}")
