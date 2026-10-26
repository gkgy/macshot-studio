"""Local-only Whisper bridge. Requires an existing faster-whisper Python environment.
No model download or outbound API calls. stdout is a machine-readable word timeline.
"""
import json, os, pathlib, sys
from faster_whisper import WhisperModel
source, model_path = sys.argv[1:3]
if not model_path:
    root = pathlib.Path.home()/'.cache/huggingface/hub/models--mobiuslabsgmbh--faster-whisper-large-v3-turbo/snapshots'
    candidates = sorted(root.glob('*/model.bin'))
    if not candidates:
        raise RuntimeError('未找到本地 Whisper 模型。请在 Studio 设置中填写模型文件夹。')
    model_path = str(candidates[-1].parent)
model = WhisperModel(model_path, device='cpu', compute_type='int8', cpu_threads=min(8, os.cpu_count() or 4), local_files_only=True)
segments, _ = model.transcribe(source, language='zh', beam_size=5, word_timestamps=True, vad_filter=True, condition_on_previous_text=False, initial_prompt='普通话视频解说，Shapr3D、Codex、Mac Studio、AI 建模、渲染。简体中文。')
words=[]
for segment in segments:
    pending=[]
    for word in segment.words or []:
        if word.end <= word.start: continue
        pending.append(word)
        text=''.join(w.word for w in pending).strip()
        if len(text)>=14 or pending[-1].end-pending[0].start>=3 or text.endswith(('。','！','？')):
            words.append(dict(text=text.replace('Sharp3D','Shapr3D'),start=pending[0].start,end=pending[-1].end));pending=[]
    if pending:
        words.append(dict(text=''.join(w.word for w in pending).strip().replace('Sharp3D','Shapr3D'),start=pending[0].start,end=pending[-1].end))
print(json.dumps(words,ensure_ascii=False))
