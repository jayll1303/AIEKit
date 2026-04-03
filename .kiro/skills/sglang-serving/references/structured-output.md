# Structured Output with SGLang

JSON schema, regex, EBNF constrained generation, function calling, and batch structured output patterns for SGLang Runtime.

## Overview

SGLang hỗ trợ constrained decoding trực tiếp trong inference engine — enforce output format at token level, không cần retry hay post-processing. Supported constraints:

| Type | Parameter | Use Case |
|---|---|---|
| JSON Schema | `json_schema` | Structured data extraction, API responses |
| Regex | `regex` | Phone numbers, emails, codes, fixed formats |
| EBNF Grammar | `ebnf` | Custom DSLs, programming languages, complex formats |

## JSON Schema Constrained Generation

### Basic JSON Schema

```python
from openai import OpenAI
import json

client = OpenAI(base_url="http://localhost:30000/v1", api_key="none")

schema = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer", "minimum": 0, "maximum": 150},
        "email": {"type": "string"},
        "skills": {
            "type": "array",
            "items": {"type": "string"},
            "minItems": 1,
            "maxItems": 5
        }
    },
    "required": ["name", "age", "email", "skills"]
}

response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[
        {"role": "user", "content": "Generate a software engineer profile"}
    ],
    extra_body={"json_schema": json.dumps(schema)},
    max_tokens=256,
)

# Output luôn valid JSON matching schema — không cần try/except parse
data = json.loads(response.choices[0].message.content)
print(data)
```

### Nested Objects

```python
schema = {
    "type": "object",
    "properties": {
        "product": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "price": {"type": "number", "minimum": 0},
                "currency": {"type": "string", "enum": ["USD", "EUR", "VND"]},
                "in_stock": {"type": "boolean"}
            },
            "required": ["name", "price", "currency"]
        },
        "reviews": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "rating": {"type": "integer", "minimum": 1, "maximum": 5},
                    "comment": {"type": "string"}
                },
                "required": ["rating", "comment"]
            }
        }
    },
    "required": ["product", "reviews"]
}

response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Generate a product with 2 reviews"}],
    extra_body={"json_schema": json.dumps(schema)},
    max_tokens=512,
)
```

### Enum Constraints

```python
schema = {
    "type": "object",
    "properties": {
        "sentiment": {"type": "string", "enum": ["positive", "negative", "neutral"]},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        "language": {"type": "string", "enum": ["en", "vi", "ja", "zh"]}
    },
    "required": ["sentiment", "confidence", "language"]
}
```

## Regex Constrained Generation

### Common Patterns

```python
# Phone number
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Generate a US phone number"}],
    extra_body={"regex": r"\(\d{3}\) \d{3}-\d{4}"},
)

# Email address
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Generate an email"}],
    extra_body={"regex": r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"},
)

# ISO date
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Generate a date"}],
    extra_body={"regex": r"\d{4}-\d{2}-\d{2}"},
)

# Hex color code
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Generate a hex color"}],
    extra_body={"regex": r"#[0-9a-fA-F]{6}"},
)
```

### Classification with Regex

```python
# Force output to be exactly one of the choices
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Is this text positive or negative: 'I love this!'"}],
    extra_body={"regex": r"(positive|negative)"},
)
# Output: "positive" — guaranteed, no parsing needed
```

## EBNF Grammar

### Basic EBNF

```python
# Simple arithmetic expression grammar
ebnf_grammar = r"""
root ::= expr
expr ::= term (("+" | "-") term)*
term ::= factor (("*" | "/") factor)*
factor ::= number | "(" expr ")"
number ::= [0-9]+
"""

response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Generate a math expression"}],
    extra_body={"ebnf": ebnf_grammar},
)
```

### SQL-like Query Grammar

```python
ebnf_grammar = r"""
root ::= select_stmt
select_stmt ::= "SELECT " columns " FROM " table where_clause?
columns ::= column ("," " " column)*
column ::= [a-zA-Z_][a-zA-Z0-9_]*
table ::= [a-zA-Z_][a-zA-Z0-9_]*
where_clause ::= " WHERE " condition
condition ::= column " " operator " " value
operator ::= "=" | "!=" | ">" | "<" | ">=" | "<="
value ::= "'" [a-zA-Z0-9_]+ "'" | [0-9]+
"""
```

### Structured Report Grammar

```python
ebnf_grammar = r"""
root ::= "## Summary\n" summary "\n\n## Findings\n" findings "\n\n## Score: " score "/10"
summary ::= sentence+
findings ::= ("- " sentence "\n")+
sentence ::= [A-Z][a-zA-Z0-9 ,.'()-]+ "." " "?
score ::= [0-9] | "10"
"""
```

## SGLang Native Client

Ngoài OpenAI client, SGLang có native Python frontend cho complex generation flows:

```python
import sglang as sgl

@sgl.function
def multi_turn_qa(s, question):
    s += sgl.system("You are a helpful assistant.")
    s += sgl.user(question)
    s += sgl.assistant(sgl.gen("answer", max_tokens=256))
    s += sgl.user("Summarize your answer in one sentence.")
    s += sgl.assistant(sgl.gen("summary", max_tokens=64))

# Run with SGLang Runtime
sgl.set_default_backend(sgl.RuntimeEndpoint("http://localhost:30000"))

state = multi_turn_qa.run(question="What is RadixAttention?")
print(state["answer"])
print(state["summary"])
```

### Native Client with Structured Output

```python
@sgl.function
def extract_info(s, text):
    s += sgl.user(f"Extract information from: {text}")
    s += sgl.assistant(
        sgl.gen("result", max_tokens=256,
                regex=r'\{"name": "[^"]+", "age": \d+\}')
    )

state = extract_info.run(text="John is 30 years old")
print(state["result"])
```

## Function Calling / Tool Use

SGLang hỗ trợ OpenAI-compatible function calling:

```python
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather for a location",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string", "description": "City name"},
                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
                },
                "required": ["location"]
            }
        }
    }
]

response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "What's the weather in Hanoi?"}],
    tools=tools,
    tool_choice="auto",
)

# Parse tool call
tool_call = response.choices[0].message.tool_calls[0]
print(f"Function: {tool_call.function.name}")
print(f"Args: {tool_call.function.arguments}")
```

## Batch Structured Generation

Xử lý nhiều requests cùng lúc với structured output:

```python
import concurrent.futures

prompts = [
    "Generate a user profile for a doctor",
    "Generate a user profile for an engineer",
    "Generate a user profile for a teacher",
]

schema = json.dumps({
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "profession": {"type": "string"},
        "years_experience": {"type": "integer"}
    },
    "required": ["name", "profession", "years_experience"]
})

def generate_one(prompt):
    return client.chat.completions.create(
        model="meta-llama/Llama-3.1-8B-Instruct",
        messages=[{"role": "user", "content": prompt}],
        extra_body={"json_schema": schema},
        max_tokens=256,
    )

# Parallel requests — SGLang handles batching internally
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
    results = list(executor.map(generate_one, prompts))

for r in results:
    data = json.loads(r.choices[0].message.content)
    print(data)
```

### Native Batch API

```python
import sglang as sgl

@sgl.function
def classify(s, text):
    s += sgl.user(f"Classify sentiment: {text}")
    s += sgl.assistant(sgl.gen("label", regex=r"(positive|negative|neutral)"))

texts = ["I love this!", "Terrible experience", "It's okay I guess"]
states = classify.run_batch(
    [{"text": t} for t in texts],
    progress_bar=True,
)

for s in states:
    print(s["label"])
```

## Performance Tips cho Structured Output

| Tip | Chi tiết |
|---|---|
| JSON schema > regex cho complex structures | JSON schema compiler tối ưu hơn regex cho nested objects |
| Regex cho simple patterns | Phone, email, date — regex nhanh hơn JSON schema |
| EBNF cho custom DSLs | Khi cần grammar phức tạp hơn JSON/regex |
| Batch requests | SGLang continuous batching xử lý parallel requests hiệu quả |
| Shared prefix + structured output | RadixAttention cache prefix → structured decoding chỉ apply cho generation tokens |
| Avoid overly complex regex | Regex quá phức tạp (nested groups, backreferences) có thể chậm |
