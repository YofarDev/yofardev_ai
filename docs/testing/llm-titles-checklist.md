# LLM-Generated Titles & Task Config Testing Checklist

## Title Generation Tests

- [ ] Create new chat
- [ ] Send first message
- [ ] Verify temporary title shows in chat list (first 50 chars of message)
- [ ] Wait for AI response to complete
- [ ] Verify title updates to AI-generated title
- [ ] Refresh app and verify title persists

### Edge Cases
- [ ] Send empty first message - should not crash
- [ ] Send very long first message - temporary title should be truncated
- [ ] Send special characters in first message - title should be sanitized
- [ ] Delete chat while title is generating - should not crash

## Task LLM Config Tests

- [ ] Navigate to Settings > Task LLM Configuration
- [ ] Verify all three task types show dropdowns
- [ ] Verify "Use default LLM" option is available
- [ ] Verify all configured LLMs appear in dropdowns
- [ ] Select different LLM for Assistant task
- [ ] Select different LLM for Title Generation task
- [ ] Select different LLM for Function Calling task
- [ ] Create new chat and verify title uses title-specific LLM
- [ ] Send function-calling message and verify it uses function-specific LLM
- [ ] Restart app and verify task config persists

## Migration Tests

- [ ] Install app version before this feature
- [ ] Update to new version
- [ ] Verify existing chats have empty title and titleGenerated: false
- [ ] Create new chat and verify title generation works
- [ ] Verify migration only runs once

## UI Tests

- [ ] Verify generated titles display correctly in chat list
- [ ] Verify temporary titles display before generation
- [ ] Verify settings page is responsive
- [ ] Verify glassmorphic styling matches app design
- [ ] Verify all text is properly localized (EN/FR)
