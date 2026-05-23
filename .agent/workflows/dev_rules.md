# Project Development Rules

## Code Quality

- Follow clean code principles
- Avoid duplicated logic
- Use modular functions
- Write readable code

## Python Guidelines

- Follow PEP8
- Use type hints when possible
- Prefer list comprehensions when readable
- Avoid deeply nested logic

## Backend Architecture

- Separate business logic from routes
- Use service layers when necessary
- Keep controllers thin

Example structure:

app/
  routes/
  services/
  models/
  utils/

## Error Handling

- Always validate inputs
- Handle exceptions gracefully
- Provide clear error messages

## Security

- Validate user input
- Avoid SQL injection risks
- Protect sensitive data

## Performance

- Avoid unnecessary loops
- Optimize database queries
- Use caching when beneficial

## Documentation

- Comment complex logic
- Write docstrings for functions