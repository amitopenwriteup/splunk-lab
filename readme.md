# Splunk Architecture Overview - Presentation Guide

A comprehensive guide to presenting the Splunk Architecture PowerPoint deck covering forwarders, indexers, search heads, log onboarding, and SPL basics.

---

## Overview

**Total Slides:** 10  
**Recommended Duration:** 20-30 minutes  
**Audience:** DevOps engineers, system administrators, IT operations, data analysts

This guide walks you through each slide with:
- Key talking points
- Detailed explanations
- Tips for engagement
- Common questions and answers

---

## Slide-by-Slide Guide

### Slide 1: Title Slide (1-2 minutes)

**What's on the slide:**
- Title: "Splunk Architecture Overview"
- Subtitle: "Data Forwarding, Indexing & Search"
- Topics listed: Architecture • Log Onboarding • Search Processing Language

**Talking Points:**
- Welcome the audience and set expectations
- Explain that this session covers the core components of Splunk: how data flows from collection to analysis
- Mention the three main topics you'll cover in order
- Note that this is foundational knowledge for working with Splunk in production

**Tips:**
- Use this slide to establish context and gauge audience familiarity with Splunk
- Ask: "Who has worked with Splunk before?" to adjust your pacing accordingly
- Set a friendly, collaborative tone

---

### Slide 2: Architecture Overview (2-3 minutes)

**What's on the slide:**
- A three-part diagram: Forwarders → Indexers → Search Heads
- Each component has a colored box and description:
  - **Forwarders (Orange):** Collect & Send Data
  - **Indexers (Blue):** Process & Store Data
  - **Search Heads (Green):** Search & Analyze

**Talking Points:**

1. **The Big Picture:**
   - Splunk follows a simple pipeline: Data Collection → Processing & Storage → Search & Analytics
   - Each component has a specific role
   - They work together to create an end-to-end observability platform

2. **Flow Explanation:**
   - Data originates from servers, applications, containers, APIs, etc.
   - Forwarders act as the "front door" - they watch your data sources and send everything to the indexers
   - Indexers are the "warehouse" - they organize and store data so it's fast to search
   - Search heads are the "dashboard" - they let you query, visualize, and analyze all that data

3. **Why This Architecture?**
   - **Scalability:** You can add more forwarders or indexers independently
   - **Reliability:** Each component can be clustered for high availability
   - **Performance:** Indexers are optimized for storage; search heads are optimized for queries

**Tips:**
- Use your hand or pointer to trace the flow left to right as you explain
- This is a good moment to pause and ask if anyone has questions about the overall concept
- Emphasize that understanding this flow is key to everything that follows

**Common Questions:**
- *Q: Can I use Splunk without all three components?*  
  A: In a basic setup, you might have forwarders sending directly to a single "all-in-one" instance. But for production, this architecture is the standard.

---

### Slide 3: Forwarders - Data Collection (3-4 minutes)

**What's on the slide:**
- Section title and definition
- Four key bullet points on what forwarders are
- Types of forwarders (Universal vs. Heavy)

**Talking Points:**

1. **What Forwarders Are:**
   - Lightweight software agents (think "sensors") deployed on your infrastructure
   - Their job is to watch log files, event logs, metrics in real-time
   - They forward data to indexers without losing anything
   - They can do basic filtering and transformation before sending

2. **Key Features:**
   - **Lightweight:** Minimal resource consumption - runs on production servers
   - **Reliable:** Data is buffered and retried if the indexer is unavailable
   - **Flexible:** Can monitor multiple files and apply different settings to each
   - **Transformable:** Can filter, rename fields, or mask sensitive data

3. **Types of Forwarders:**
   - **Universal Forwarder:** The standard choice. Small footprint, can send from any source
   - **Heavy Forwarder:** Legacy option. Larger, can do more processing locally, rarely used today

4. **Deployment Scenarios:**
   - App servers → Forwarder → Indexer
   - Web servers → Forwarder → Indexer
   - Containers → Forwarder → Indexer
   - Cloud services → Forwarder → Indexer

**Tips:**
- Show a relatable example: "Think of a forwarder like a mail carrier. It picks up mail (logs) from various mailboxes (log files) and delivers it to the post office (indexer)."
- Emphasize that forwarders are non-intrusive - they just read, they don't modify your app
- This is a good place to mention version compatibility if relevant to your environment

**Common Questions:**
- *Q: What if a forwarder loses connection to the indexer?*  
  A: It will buffer the data locally and retry. Once connection is restored, it sends buffered data.

- *Q: Can one forwarder send to multiple indexers?*  
  A: Yes! For redundancy, you can configure load balancing to multiple indexers.

- *Q: What's the overhead of running a forwarder?*  
  A: Typically very minimal - less than 1% CPU and memory on most systems.

---

### Slide 4: Indexers - Data Processing & Storage (3-4 minutes)

**What's on the slide:**
- Section title and what indexers do
- Five key bullet points describing indexer functions

**Talking Points:**

1. **The Indexer's Role:**
   - Receives raw data from forwarders
   - Parses the data into "events" (individual log entries)
   - Creates highly optimized searchable indexes
   - Stores both the raw data and metadata

2. **What "Indexing" Means:**
   - Splunk breaks data into fields (timestamp, source, hostname, etc.)
   - Creates indexes - special data structures that make searching fast
   - Similar to how a book index lets you find topics instantly instead of reading every page
   - This is what makes Splunk searches so fast (milliseconds on terabytes)

3. **Key Responsibilities:**
   - **Parsing:** Extract fields and identify event boundaries
   - **Storage:** Write data to disk in compressed, searchable format
   - **Retention:** Enforce data retention policies (30 days, 1 year, etc.)
   - **Bucket Management:** Organize data into "buckets" (time-based directories)
   - **Clustering:** In production, indexers form clusters for redundancy

4. **Data Lifecycle on an Indexer:**
   - Hot bucket: Currently receiving new data (writable)
   - Warm bucket: Older data, searchable but not receiving new events
   - Cold bucket: Oldest data, moved to cheaper storage
   - Frozen/Archived: Data reaches retention limit

**Tips:**
- Use the book analogy to explain indexing - it resonates well
- Show that indexing is what makes Splunk different from just storing raw logs
- Mention storage efficiency: Splunk typically compresses data 10-20x
- If your audience is technical, you can mention "inverted index" structures

**Common Questions:**
- *Q: How much disk space will I need?*  
  A: It depends on your data volume and retention. As a rule, expect raw data to be 10-20% of the original size after compression.

- *Q: Can I search data that's not yet indexed?*  
  A: No, Splunk must index data before you can search it. This is why indexing speed matters.

- *Q: What happens if an indexer fails?*  
  A: In a cluster, replicas on other indexers provide failover. Non-clustered setups lose data in flight.

---

### Slide 5: Search Heads - Analytics & Visualization (3-4 minutes)

**What's on the slide:**
- Section title and question "What are search heads?"
- Five bullet points describing search head functions
- Deployment note about separation from indexers

**Talking Points:**

1. **The Search Head's Role:**
   - The user-facing component - this is where you search and analyze
   - Executes Splunk queries and aggregates results from multiple indexers
   - Provides the web UI you interact with
   - Creates and manages dashboards, reports, and alerts

2. **Search Execution:**
   - When you run a search, the search head breaks it into parts
   - Sends sub-searches to indexers to process their local data
   - Collects and combines results from all indexers
   - Returns aggregated results to you

3. **Key Capabilities:**
   - **Saved Searches:** Reusable queries you run on a schedule
   - **Dashboards:** Combine multiple searches into visual reports
   - **Alerts:** Trigger actions (emails, webhooks) when conditions are met
   - **Field Extraction:** Define how to extract structured data from logs
   - **Data Enrichment:** Add additional context to data at search time

4. **Architecture Note:**
   - In production, search heads are **separate** from indexers
   - They communicate via REST API over the network
   - This separation allows independent scaling
   - Search heads can be clustered for high availability

5. **User Interface:**
   - Web interface (what most users interact with)
   - Splunk CLI (command-line interface)
   - REST API (for integrations and automation)

**Tips:**
- If possible, show a quick demo of the Splunk web interface
- Emphasize that search heads handle the "thinking" while indexers handle the "storage"
- This is where end users spend most of their time
- Good time to show an example dashboard

**Common Questions:**
- *Q: Can I search without a search head?*  
  A: Technically you can use CLI on an indexer, but the search head provides the primary interface and capabilities.

- *Q: Can I run searches on multiple search heads?*  
  A: Yes, you can cluster search heads for load distribution. All share the same view of indexed data.

- *Q: How long do searches take?*  
  A: Depends on data volume and query complexity. Simple searches on indexed data can return results in milliseconds. Complex queries might take minutes.

---

### Slide 6: Onboarding Application & API Logs (4-5 minutes)

**What's on the slide:**
- Three steps for onboarding logs:
  1. Install & Configure Forwarder
  2. Define Input Stanzas
  3. Configure Indexer Outputs

**Talking Points:**

1. **Step 1: Install & Configure Forwarder (1-2 min)**
   - Download Universal Forwarder appropriate for your OS
   - Install on the server where your application runs
   - Basic configuration:
     - Point it to your indexer hostname and port (typically 9997)
     - Create inputs.conf file to specify what to monitor
   - Restart the forwarder service
   - Verify connectivity to the indexer

2. **Step 2: Define Input Stanzas (1-2 min)**
   - An "input stanza" is a configuration block for one data source
   - For each log file, you define:
     - **source:** Physical file path (e.g., /var/log/app.log)
     - **sourcetype:** What kind of data it is (e.g., myapp:logs)
     - **index:** Which Splunk index to send it to (main, custom, etc.)
     - **disabled:** Whether to monitor it (true/false)
   - You can apply transformations (filter, rename fields)
   - Multiple stanzas in one inputs.conf file

3. **Step 3: Configure Indexer Outputs (1 min)**
   - Edit outputs.conf on the forwarder
   - Configure where to send data (indexer hostname and port)
   - Set up load balancing if using multiple indexers
   - Connection parameters (SSL, authentication, etc.)
   - Test connectivity: `telnet indexer-hostname 9997`

4. **End-to-End Flow:**
   - Forwarder reads from log file
   - Sends to indexer every few seconds (or when buffer fills)
   - Indexer receives, parses, and indexes
   - Data appears in Splunk search within seconds

**Workflow Diagram (describe):**
   ```
   Application writes logs → Forwarder reads → Forwarder sends → 
   Indexer receives → Indexer indexes → Search head queries → Results
   ```

**Tips:**
- Walk through the steps sequentially - don't skip ahead
- Emphasize that this is the most common task - getting data into Splunk
- Show that it's not complicated, just methodical
- Mention that troubleshooting involves checking forwarder logs if data doesn't appear

**Common Questions:**
- *Q: What if I want to monitor multiple log files?*  
  A: Create separate input stanzas in inputs.conf, one per file (or use wildcards like /var/log/*.log).

- *Q: Can I filter logs on the forwarder to reduce data volume?*  
  A: Yes, using props.conf and transforms.conf, but the slide doesn't go into that detail.

- *Q: How do I know if data is being sent?*  
  A: Check forwarder logs in $SPLUNK_HOME/var/log/splunk/, and search in Splunk for your sourcetype.

- *Q: What's the difference between "source" and "sourcetype"?*  
  A: Source is the file path (specific), sourcetype is the data type (category). Helpful for organization.

---

### Slide 7: Configuration Example - inputs.conf (2-3 minutes)

**What's on the slide:**
- Title: "Configuration Example: inputs.conf"
- Dark gray code block showing sample configuration

**Sample Config Explanation:**

```
[monitor:///var/log/myapp/application.log]
sourcetype = myapp:logs
source = myapp
index = main
disabled = false

[monitor:///var/log/myapp/api.log]
sourcetype = myapp:api
source = myapp_api
index = main
disabled = false
```

**Talking Points:**

1. **Breaking Down the Config:**
   - `[monitor:///var/log/myapp/application.log]` - Header specifying the file to monitor (note the three slashes for absolute path)
   - `sourcetype = myapp:logs` - Classification of this data (convention: app:logtype)
   - `source = myapp` - Identifier for the source
   - `index = main` - Splunk index where this data goes (main is default)
   - `disabled = false` - Whether this input is active

2. **Real-World Scenario:**
   - Application server running "myapp"
   - Two separate log files (application logs and API logs)
   - Each needs different sourcetype for proper parsing
   - Both go to the same "main" index

3. **Key Points:**
   - You can have multiple `[monitor:]` stanzas in one file
   - Naming convention `app:type` is a best practice
   - Path must be absolute (full path from root)
   - Splunk will auto-detect when new data arrives

4. **Common Variations:**
   - `[monitor:///var/log/*.log]` - Wildcards work
   - Different indexes for different log types
   - Adding `whitelist` or `blacklist` to filter files
   - `time_before_close = 30` to specify how long to keep file open

**Tips:**
- This is a real, working configuration - emphasize it's not theoretical
- Point out the specific syntax (the three slashes, the equals signs, format)
- Show how organized naming conventions help later
- Good time to offer to answer questions about their specific files

**Common Questions:**
- *Q: Can I monitor a log file that rotates daily?*  
  A: Yes, Splunk handles log rotation automatically by tracking inode numbers.

- *Q: What if the path doesn't exist yet?*  
  A: Splunk will wait and start monitoring when the file is created.

- *Q: Can I use relative paths?*  
  A: No, always use absolute paths. Splunk runs as a service and can't rely on working directory.

---

### Slide 8: Search Processing Language (SPL) Basics (4-5 minutes)

**What's on the slide:**
- Definition of SPL
- Basic structure diagram: `search_terms | command1 | command2 | command3`
- Two columns:
  - Common Commands: stats, fields, where, top, timechart
  - Common Operators: AND, OR, NOT, =, <, >, <=, >=, !=

**Talking Points:**

1. **What is SPL? (1 min)**
   - Splunk's proprietary query language for searching and analyzing data
   - Designed to be relatively intuitive for sysadmins and operators
   - Composed of commands chained together with pipes (|)
   - Each command takes input and produces output for the next command

2. **Anatomy of a Query (1 min)**
   ```
   search_terms | command1 | command2 | command3
   ```
   - **search_terms:** Initial filter to find relevant events
   - **|:** "Pipe" - passes output to the next command
   - **commands:** Each does a specific operation (filter, aggregate, transform, etc.)
   - Reading left to right: Find events → Process them → Aggregate → Visualize

3. **Common Commands (explain each):**
   - **stats:** Aggregate and calculate (count, sum, avg, etc.)
   - **fields:** Select specific fields to display
   - **where:** Filter results based on conditions
   - **top:** Find the most frequent values
   - **timechart:** Create time-series data for graphing

4. **Common Operators:**
   - **AND, OR, NOT:** Boolean logic for combining conditions
   - **=, <, >, <=, >=, !=:** Comparison operators
   - Example: `status >= 400 AND status < 500` finds HTTP errors
   - Example: `level="ERROR" OR level="CRITICAL"`

5. **Query Execution Order:**
   - Splunk reads from left to right
   - Search terms are processed first (filtering data)
   - Commands are applied in sequence
   - Each stage narrows or transforms the result set

**Visual Concept to Explain:**
   ```
   All Events (millions)
   ↓ (search filters)
   Relevant Events (thousands)
   ↓ (stats aggregates)
   Summary Statistics (10 rows)
   ↓ (display formats)
   Results or Chart
   ```

**Tips:**
- Emphasize that SPL is a "pipe and filter" architecture - very powerful concept
- Don't overwhelm with all SPL commands - there are hundreds. Stick to the common ones
- The next slide will have concrete examples, so this is foundation-setting
- Good time to ask: "Has anyone used command-line pipes in Unix/Linux?" - draws parallel

**Common Questions:**
- *Q: Is SPL like SQL?*  
  A: Similar in some ways, but different. SPL is optimized for log analysis. SQL is for databases.

- *Q: How many commands can I chain together?*  
  A: Theoretically many, but practically 5-10 is typical. Performance degrades with too many stages.

- *Q: Can I save searches?*  
  A: Yes, that's a search head feature. Saved searches are the foundation of dashboards and alerts.

---

### Slide 9: SPL Examples (5-7 minutes)

**What's on the slide:**
- Three real-world SPL query examples with explanations
- Each in a code box with clear syntax

**Example Explanations:**

**Example 1: Filter Errors**
```
sourcetype=myapp:logs level=ERROR | fields timestamp, message, user
```
- **What it does:** Find all ERROR-level logs from your app, show when, what, and who
- **Breakdown:**
  - `sourcetype=myapp:logs` - Limit to logs from myapp (search term)
  - `level=ERROR` - Only errors (additional filter)
  - `| fields` - Select specific fields to display
  - Result: Clean table of errors with timestamp, message, user
- **Use case:** Troubleshooting a problem - see errors as they occurred and who triggered them

**Example 2: Count Events by Status**
```
sourcetype=myapp:api | stats count by status_code
```
- **What it does:** See how many API calls returned each status code
- **Breakdown:**
  - `sourcetype=myapp:api` - Get API logs
  - `| stats count` - Count total events
  - `by status_code` - Break down count by each status code
  - Result: Table like:
    ```
    status_code | count
    200         | 45000
    201         | 2000
    400         | 150
    500         | 10
    ```
- **Use case:** Health monitoring - see if your API is mostly healthy (lots of 200s) or having issues

**Example 3: Top 10 Users**
```
sourcetype=myapp:logs | stats count by user | top 10 user
```
- **What it does:** Find the 10 users who generated the most log entries
- **Breakdown:**
  - `sourcetype=myapp:logs` - Get app logs
  - `| stats count by user` - Count events per user
  - `| top 10 user` - Sort and show top 10
  - Result: Leaderboard of most-active users
- **Use case:** Capacity planning, finding power users, identifying unusual behavior patterns

**Interactive Element:**
- Walk through one example step-by-step
- "If I run this query right now on our data, what would you expect to see?"
- Engage audience in predicting results

**Tips:**
- These are simple, realistic examples - not overly complex
- Point out the pattern: search → aggregate → format
- Show how the pipe | is the key to building complex logic
- Offer to customize examples to their specific logs/metrics

**Common Questions:**
- *Q: How long do these queries take to run?*  
  A: On indexed data, usually 1-10 seconds depending on data volume and time range searched.

- *Q: Can I make these queries run automatically?*  
  A: Yes, these can be saved searches that run on a schedule and send alerts or create reports.

- *Q: What if a field doesn't exist in my logs?*  
  A: You'll get 0 results or the field will be missing. You may need to extract fields or adjust your query.

- *Q: Can I combine multiple commands in one query?*  
  A: Yes! That's the power of pipes. You can do: search | filter | aggregate | sort | top | chart

---

### Slide 10: Summary (2-3 minutes)

**What's on the slide:**
- Five key takeaways presented as bullet points

**Talking Points:**

1. **Recap the Architecture:**
   - "Let's zoom out and remember the big picture we started with"
   - Forwarders collect → Indexers store → Search heads analyze
   - Three distinct components, each with a specific job
   - Together they create a complete observability platform

2. **Key Takeaways:**
   - **Forwarders collect data** from your applications and servers
   - **Indexers process and store** the data in searchable indexes
   - **Search Heads provide the interface** for querying and analyzing data
   - **SPL is the powerful query language** for extracting insights
   - **End-to-end pipeline:** Data Collection → Processing → Search & Analysis

3. **What's Next?**
   - Onboarding your first data source
   - Writing your first search
   - Creating dashboards and alerts
   - Setting up monitoring and alerting

4. **Practical Next Steps:**
   - Identify log files to send to Splunk
   - Install and configure forwarders
   - Write searches to answer business questions
   - Share dashboards with your team

5. **Closing Thoughts:**
   - Splunk is powerful because it's simple at the core
   - Start with these fundamentals - they apply to everything
   - Once you understand the architecture, advanced features become natural

**Tips:**
- Use this to reinforce what was covered - don't introduce new concepts
- This is the moment to inspire action - suggest concrete next steps
- Leave time for final questions
- Offer yourself as a resource for implementation

---

## Tips for Effective Presentation

### General Best Practices

1. **Engagement:**
   - Pause frequently for questions
   - Use relatable analogies (mail carrier, book index, etc.)
   - Make eye contact with audience members
   - Vary your tone and pace to maintain interest

2. **Pacing:**
   - Don't rush through - give people time to absorb
   - Spend more time on unfamiliar concepts
   - Be flexible - if audience has lots of questions about forwarders, spend extra time there
   - Use the 80/20 rule: 80% talking, 20% listening/questions

3. **Handling Questions:**
   - Encourage questions throughout, not just at the end
   - If you don't know an answer, be honest: "That's a great question - let me research that and get back to you"
   - Use questions to gauge understanding
   - Rephrase questions before answering to ensure you understood correctly

4. **Visual Aids:**
   - Use the slides as a guide, not a script
   - Don't read slides verbatim - add context and examples
   - Point at the diagram on Slide 2 frequently
   - Show the code examples and explain what each part does

5. **Customization:**
   - Adapt examples to your organization's actual tools and log formats
   - Reference real dashboards or searches your team uses
   - Share actual data volumes and retention policies
   - Show real-world scenarios they'll encounter

### Handling Different Audience Types

**If audience is mostly non-technical:**
- Use more analogies and fewer technical details
- Avoid jargon or explain it simply
- Focus on "what" and "why", less on "how"
- Show practical benefits and use cases

**If audience is very technical:**
- Dig deeper into architecture and performance
- Discuss indexing structures and optimization
- Talk about clustering, failover, and tuning
- Suggest advanced SPL concepts they'll explore

**If audience is mixed:**
- Start simple and layer in complexity
- Offer to do deep-dives separately for technical folks
- Use examples that appeal to both groups
- Make it clear that advanced topics are available for those interested

### Handling Common Challenges

**"Splunk is too slow"**
- Likely a search optimization issue
- Suggest narrowing time ranges or using indexed extractions
- Offer to review their query structure
- Mention search head and indexer tuning

**"We have too much data"**
- True - many environments do
- Discuss selective forwarding and filtering
- Index organization and retention strategies
- Data enrichment at search time instead of index time

**"Setup seems complicated"**
- It's not once you do it a few times
- Offer to help with first few data sources
- Provide templates and documentation
- Mention automation tools and apps

---

## Sample Dialog for Key Slides

### Opening the Presentation

"Good [morning/afternoon], everyone. Thanks for joining me. Today we're going to cover the fundamentals of Splunk architecture. If you've ever wondered how Splunk takes raw logs and turns them into searchable data, or if you're getting ready to send your first data source to Splunk, this session is for you.

We'll walk through three main topics. First, the architecture - the three core components and how they work together. Then we'll get practical: how to actually get your application logs into Splunk. And finally, we'll look at the query language you'll use to find insights in that data.

By the end of this session, you'll understand the complete flow from data source to search result. You'll be ready to set up your own forwarders and write your first queries. Let's get started."

### Transitioning Between Sections

"Great questions on forwarders. Now that we understand how data is collected, let's look at what happens when it reaches Splunk - that's the indexers. This is where the magic happens."

---

## Discussion Questions

Use these to check understanding and keep engagement high:

1. "Why do you think Splunk separates indexers and search heads instead of having one component?"
   - *Expected answer:* Scalability, independent optimization, reliability

2. "If a forwarder loses connection to the indexer, what do you think happens to the logs?"
   - *Expected answer:* Buffered locally, retried when connection restored

3. "What would happen if you sent all your logs to Splunk without any filtering?"
   - *Expected answer:* High storage costs, slower searches, too much noise

4. "How is a Splunk search similar to or different from a database query?"
   - *Expected answer:* Similar: selecting, filtering, aggregating. Different: designed for unstructured logs, inverted index

5. "Can you think of a question you'd like to answer about your application logs that would require a Splunk search?"
   - *Expected answer:* Open-ended - validates real interest and use cases

---

## Troubleshooting Common Presentation Issues

**Issue: Audience seems confused about indexing**
- Use the book analogy more explicitly
- Draw a simple diagram on a whiteboard
- Show before/after: raw logs vs. indexed data
- Use a search head example: "Without indexes, every search would need to read every log file from scratch"

**Issue: Too many questions are slowing you down**
- It's OK! Questions mean engagement
- You can offer: "This is a great question - let's discuss it after the main presentation"
- Or: "Let's add this to our parking lot and circle back if we have time"

**Issue: Running out of time**
- Skip or quickly summarize the configuration example (Slide 7) if needed
- Focus on Slides 1-5 (architecture) as core material
- Save SPL details (Slides 8-9) for a follow-up session if needed

**Issue: Audience wants to see a live demo**
- If possible, show a live search on your Splunk instance
- Even a simple one (like Example 1) impresses and solidifies understanding
- If not prepared, offer to do a demo separately

---

## Post-Presentation Follow-ups

After the presentation, consider:

1. **Share the slides** with all attendees (email or shared drive)

2. **Offer hands-on session:**
   - "Who's ready to set up their first forwarder? I can help walk through it"

3. **Create cheat sheet:**
   - Commonly used SPL commands and examples
   - Configuration templates
   - Troubleshooting guide

4. **Set up office hours:**
   - "I'm available Thursdays 2-3pm for Splunk questions"
   - Builds community and helps adoption

5. **Get feedback:**
   - "What was most helpful?"
   - "What do you want to learn next?"
   - Adjust future sessions based on feedback

---

## Additional Resources to Reference

**For More Learning:**
- Splunk Fundamentals Part 1 (online course)
- Splunk Documentation: docs.splunk.com
- Splunk Answers: answers.splunk.com (Q&A community)
- Internal wiki or documentation for your organization's setup

**For Troubleshooting:**
- Forwarder logs: $SPLUNK_HOME/var/log/splunk
- Index health checks in Splunk UI
- Deployment monitoring apps
- Splunk support (if enterprise customer)

---

## Final Notes

- **This is foundational knowledge** - Once people understand this architecture, everything else in Splunk makes sense
- **Repetition helps** - Don't hesitate to explain the same concept multiple times in different ways
- **Real examples are powerful** - Use their data, their logs, their infrastructure
- **Celebrate small wins** - Getting first data in is a milestone worth acknowledging
- **You're enabling your team** - By teaching Splunk, you're giving them powerful tools for better monitoring and faster troubleshooting

Good luck with your presentation!
