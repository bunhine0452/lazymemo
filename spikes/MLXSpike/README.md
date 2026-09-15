# MLXSpike — Qwen3-4B-Instruct-2507/MLX 비교 경로

`mlx-swift-lm` **3.31.4** 고정. 이 세션에서는 **컴파일하지 않았다** — mlx-swift 빌드 산출물과 Qwen 가중치(약 2.3GB)를
용량 때문에 미뤘다. 비교가 필요해질 때(명세 조사 문서 §5 결정 규칙: E2B 가 한국어 품질에 실패하거나 폰 비교) 아래를 따른다.

## 가중치 — 파일 단위, revision 고정

`mlx-community/Qwen3-4B-Instruct-2507-4bit` revision `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b`,
`model.safetensors` 2,263,022,417 bytes. 저장소 전체 snapshot 대신 필요한 파일만 받는다.

```sh
R=50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b
D=~/Library/Caches/lazymemo-models/Qwen3-4B-Instruct-2507-4bit; mkdir -p "$D"; cd "$D"
for f in config.json generation_config.json tokenizer.json tokenizer_config.json special_tokens_map.json \
         added_tokens.json chat_template.jinja merges.txt vocab.json model.safetensors model.safetensors.index.json; do
  curl -L -C - -o "$f" "https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit/resolve/$R/$f"
done
```

## 돌리기

```sh
cd spikes/MLXSpike
swift run -c release mlx-spike bench --model ~/Library/Caches/lazymemo-models/Qwen3-4B-Instruct-2507-4bit \
  --fixtures ../../Tests/Fixtures/Assistant --device "…" --out ../../docs/research/local-model-benchmark-$(date +%F)-mlx.md
```

- 첫 빌드는 mlx-swift(C++/Metal)와 swift-syntax(macro)를 컴파일한다. 수 분, `.build` 수 GB.
- Qwen3-Instruct-2507 은 non-thinking 전용이다. Qwen3.5 계열을 넣을 때는 template 의 `enable_thinking=false` 적용을 먼저 검사한다.
- 취소는 스트림 소비를 끊는 방식이다. 엔진이 GPU 작업을 실제로 멈추는 시점은 따로 재야 한다.
