# Development Standards & Requirements

## Code Quality Principles

### Expert-Level Code Standards

All code must follow these principles:

1. **Simplicity First**
   - Write the simplest solution that solves the problem
   - Avoid premature optimization
   - Prefer clarity over cleverness
   - Less code is better code

2. **Clean Code**
   - Self-documenting code with clear names
   - Single Responsibility Principle (SRP)
   - Don't Repeat Yourself (DRY)
   - Keep functions small and focused
   - Use meaningful variable names

3. **SOLID Principles**
   - **S**ingle Responsibility: One reason to change
   - **O**pen/Closed: Open for extension, closed for modification
   - **L**iskov Substitution: Subtypes must be substitutable
   - **I**nterface Segregation: Many specific interfaces > one general
   - **D**ependency Inversion: Depend on abstractions, not concretions

4. **Design Patterns**
   - Use appropriate patterns: Strategy, Observer, Factory, etc.
   - Redux pattern for state management
   - Repository pattern for data access
   - Service layer for business logic
   - Avoid over-engineering

5. **Swift Best Practices**
   - Value types (struct) over reference types (class) when possible
   - Protocol-oriented programming
   - Optionals for nullability
   - Error handling with Result/throws
   - Sendable for concurrency
   - Codable for serialization

6. **Testing Requirements**
   - **100% test coverage for business logic**
   - Real tests that verify behavior, not implementation
   - Test edge cases and error conditions
   - Integration tests for critical flows
   - No mocking unless absolutely necessary
   - Tests must be fast and deterministic

7. **Commit Standards**
   - **Only commit when ALL tests pass**
   - No commented-out code
   - No console.log/print statements (except intentional logging)
   - No unused imports
   - Run swift test before every commit
   - Conventional commit messages

8. **Modern Packages**
   - Use latest stable versions
   - Prefer Swift-native solutions
   - Minimal dependencies
   - Well-maintained packages only

## Testing Philosophy

### What Makes a "Real" Test?

✅ **Good Test (Real)**
```swift
func testArticleMarkAsRead() {
    var article = Article(/* ... */)
    XCTAssertFalse(article.isRead)

    article.markAsRead()

    XCTAssertTrue(article.isRead)
    XCTAssertNotEqual(article.updatedAt, article.addedAt)
}
```

❌ **Bad Test (Fake)**
```swift
func testArticleExists() {
    let article = Article(/* ... */)
    XCTAssertNotNil(article) // Useless test
}
```

### Test Coverage Requirements

- **Models**: 100% - Every method, every edge case
- **State/Reducers**: 100% - Every action, every state transition
- **Services**: 90%+ - All business logic paths
- **Components**: 80%+ - Critical rendering logic
- **Integration**: Key user flows end-to-end

### Test Naming Convention

```swift
// Pattern: test_<scenario>_<expectedBehavior>
func test_addArticle_addsToStateAndAllIds()
func test_markAsRead_whenArticleExists_updatesReadStatus()
func test_fetchFeed_withInvalidURL_throwsError()
```

## Code Review Checklist

Before committing, verify:

- [ ] All tests pass (`swift test`)
- [ ] No compiler warnings
- [ ] Code follows SOLID principles
- [ ] Functions < 20 lines (guideline)
- [ ] No duplicate code
- [ ] Error handling present
- [ ] Types are Sendable where appropriate
- [ ] Documentation for public APIs
- [ ] No force unwrapping (!) except where proven safe
- [ ] Performance considered (O(n) not O(n²))

## Anti-Patterns to Avoid

❌ **God Objects**: Classes doing too much
❌ **Primitive Obsession**: Using String/Int instead of types
❌ **Magic Numbers**: Unexplained constants
❌ **Shotgun Surgery**: One change affects many files
❌ **Feature Envy**: Method using another object's data
❌ **Inappropriate Intimacy**: Classes knowing too much about each other
❌ **Lazy Class**: Class doing almost nothing
❌ **Swiss Army Knife**: Class with too many unrelated methods

## Performance Guidelines

- O(1) lookups with dictionaries (byId pattern)
- O(log n) with binary search when needed
- Avoid O(n²) nested loops
- Lazy evaluation with Computed signals
- Virtual scrolling for large lists
- Debounce expensive operations (search, NLP)
- Background processing in Web Workers

## Documentation Standards

```swift
/// Clear, concise one-line summary
///
/// Detailed explanation if needed.
/// Multiple paragraphs are fine.
///
/// - Parameters:
///   - article: The article to process
///   - force: Force processing even if already done
/// - Returns: Processed article with NLP results
/// - Throws: NLPError if processing fails
public func processArticle(_ article: Article, force: Bool = false) throws -> Article {
    // Implementation
}
```

## Security & Privacy

- No data sent to external servers
- Sanitize HTML content (XSS protection)
- Validate URLs before fetching
- Content Security Policy headers
- No tracking or analytics
- No third-party scripts

## Accessibility (a11y)

- Semantic HTML
- ARIA labels where needed
- Keyboard navigation
- Focus management
- Color contrast (WCAG AA)
- Screen reader testing

---

**Remember**: Code is read more than written. Write for the next developer (your future self).

**Motto**: "Make it work, make it right, make it fast" - in that order.
