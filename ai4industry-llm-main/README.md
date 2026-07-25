# AI4Industry Hackathon LLM-based Agent

This LLM-based agent plans and executes actions to fulfill a delegated goal. The plan is built as a Behavioral Tree, which is generated the knowledge representation of the machines in the production line.

## Prerequisites

* [Python 3+](https://www.python.org/)
* [Pip](https://pypi.org/project/pip/)

## Installation

Clone the repository and execute the following commands

```
cd ai4industry-llm
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Configuration

1. Copy the `.env.example` file to `.env` file and set the variables:

**LLM_PROVIDER**=[`openai`|`mistral`]

**LLM_MODEL**= [Name of the LLM Model]

**LLM_REASONING_EFFORT**=[`low`|`medium`|`high`]

**OPENAI_API_KEY**= [Your OpenAI API key]

**MISTRAL_API_KEY**= [Your Mistral API key]

**SIMULATOR_GROUP**= [Number of the Group Assigned]

2. Edit the `Discovery Process` section in the `src/discovery/prompts.py` file to guide the LLM agent to discover the resources required for the planning.

3. Edit the `Planning Guidance` section in the `src/planning/prompts.py` file to guide the LLM agent to generate the plan as a Behavioral Tree using the discovered resources.

## Running

In a terminal, execute
`python llmbridge.py`

## Authors
* [Alexandru Sorici](https://cs.pub.ro/team/alexandru.sorici)
* [Andrei Olaru](https://cs.pub.ro/team/andrei.olaru)
