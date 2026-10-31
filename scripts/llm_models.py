from openai import OpenAI

for model in sorted(OpenAI().models.list(), key=lambda m: m.id):
    if model.id.startswith(("gpt", "o")):
        print(model.id)
