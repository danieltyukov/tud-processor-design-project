import sys

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file) as f:
    lines = f.readlines()

# Skip header lines (memory_initialization_radix and memory_initialization_vector)
words = []
for line in lines:
    line = line.strip().rstrip(';').rstrip(',')
    if line.startswith('memory_initialization'):
        continue
    if line:
        words.append(line.zfill(8))

with open(output_file, 'w') as f:
    for i in range(0, len(words), 4):
        chunk = words[i:i+4]
        while len(chunk) < 4:
            chunk.append('00000013')
        f.write(''.join(chunk) + '\n')