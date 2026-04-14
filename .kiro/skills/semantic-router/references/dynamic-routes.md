# Dynamic Routes Guide

Dynamic routes use LLM to extract parameters from user input for function calling.

## When to Load

Load when: implementing function calling, multi-function routes, or parameter extraction.

## Single Function Route

```python
from semantic_router import Route
from semantic_router.llms.openai import get_schemas_openai

def power(base: float, exponent: float) -> float:
    """Raise base to the power of exponent.
    
    Args:
        base (float): The base number.
        exponent (float): The exponent to which the base is raised.
    
    Returns:
        float: The result of base raised to the power of exponent.
    """
    return base ** exponent

schemas = get_schemas_openai([power])

math_route = Route(
    name="math",
    utterances=[
        "what is x to the power of y?",
        "calculate the result of base 10 and exponent 3",
        "return 2 to the power of 8",
    ],
    function_schemas=schemas,
)
```

## Multi-Function Route

A single route can trigger multiple functions based on user input:

```python
from datetime import datetime
from zoneinfo import ZoneInfo

def get_time(timezone: str) -> str:
    """Finds the current time in a specific timezone.
    :param timezone: IANA timezone like "America/New_York"
    """
    now = datetime.now(ZoneInfo(timezone))
    return now.strftime("%H:%M")

def get_time_difference(timezone1: str, timezone2: str) -> str:
    """Calculates time difference between two timezones.
    :param timezone1: First IANA timezone
    :param timezone2: Second IANA timezone
    """
    now_utc = datetime.utcnow().replace(tzinfo=ZoneInfo("UTC"))
    tz1_offset = now_utc.astimezone(ZoneInfo(timezone1)).utcoffset().total_seconds()
    tz2_offset = now_utc.astimezone(ZoneInfo(timezone2)).utcoffset().total_seconds()
    hours_diff = (tz2_offset - tz1_offset) / 3600
    return f"Difference: {hours_diff} hours"

def convert_time(time: str, from_timezone: str, to_timezone: str) -> str:
    """Converts time from one timezone to another.
    :param time: Time in HH:MM format
    :param from_timezone: Source IANA timezone
    :param to_timezone: Target IANA timezone
    """
    today = datetime.now().date()
    time_obj = datetime.strptime(f"{today} {time}", "%Y-%m-%d %H:%M")
    time_obj = time_obj.replace(tzinfo=ZoneInfo(from_timezone))
    converted = time_obj.astimezone(ZoneInfo(to_timezone))
    return converted.strftime("%H:%M")

# Generate schemas for all functions
functions = [get_time, get_time_difference, convert_time]
schemas = get_schemas_openai(functions)

# Single route handles all timezone operations
timezone_route = Route(
    name="timezone_management",
    utterances=[
        # get_time utterances
        "what is the time in New York?",
        "current time in Berlin?",
        # get_time_difference utterances
        "how many hours ahead is Tokyo from London?",
        "time difference between Sydney and Cairo",
        # convert_time utterances
        "convert 15:00 from New York time to Berlin time",
        "change 09:00 from Paris time to Moscow time",
        # Combined
        "What is the time in Seattle? What is the time difference between Mumbai and Tokyo?",
    ],
    function_schemas=schemas,
)
```

## Parsing Multi-Function Response

```python
response = sr("""
    What is the time in Prague?
    What is the time difference between Frankfurt and Beijing?
    What is 5:53 Lisbon time in Bangkok time?
""")

# response.function_call contains list of all matched functions
for call in response.function_call:
    func_name = call["function_name"]
    args = call["arguments"]
    
    if func_name == "get_time":
        print(get_time(**args))
    elif func_name == "get_time_difference":
        print(get_time_difference(**args))
    elif func_name == "convert_time":
        print(convert_time(**args))
```

## Function Schema Requirements

For `get_schemas_openai()` to work correctly:

1. Function must have type hints for all parameters
2. Docstring must describe each parameter clearly
3. Use `:param name:` or `Args:` format in docstring

```python
# ✅ Good - clear types and descriptions
def search(query: str, limit: int = 10) -> list:
    """Search for items matching query.
    
    :param query: Search term to look for
    :param limit: Maximum number of results (default 10)
    :return: List of matching items
    """
    pass

# ❌ Bad - missing types and descriptions
def search(query, limit=10):
    """Search for items."""
    pass
```

## Custom Schema (Manual)

If `get_schemas_openai()` doesn't work for your function:

```python
custom_schema = {
    "name": "custom_function",
    "description": "Does something custom",
    "parameters": {
        "type": "object",
        "properties": {
            "param1": {
                "type": "string",
                "description": "First parameter"
            },
            "param2": {
                "type": "integer",
                "description": "Second parameter"
            }
        },
        "required": ["param1"]
    }
}

route = Route(
    name="custom",
    utterances=["..."],
    function_schemas=[custom_schema],
)
```

## Local LLM for Dynamic Routes

Use local LLM instead of OpenAI for parameter extraction:

```python
from semantic_router.llms import LlamaCppLLM

llm = LlamaCppLLM(
    model_path="path/to/mistral-7b.gguf",
    n_ctx=4096,
    n_gpu_layers=-1,  # Use all GPU layers
)

sr = SemanticRouter(
    encoder=encoder,
    routes=routes,
    llm=llm,  # Use local LLM for dynamic routes
)
```

**Note:** Local models like Mistral 7B often outperform GPT-3.5 for parameter extraction tasks.
