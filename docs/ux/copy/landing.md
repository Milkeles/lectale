# Copy: landing page and app entry

| | |
|---|---|
| **Status** | Concept copy for the design lead. English only. |
| **Date** | 2026-11-21 |
| **Sources** | `docs/ux/concepts/2026-11-21-landing-brief.md`, `spec/v4.0/docs/CORE_EXPERIENCE_AND_CATALOG.md`, `spec/v4.0/docs/IMPLEMENTATION_DECISIONS.md`, `apps/flutter_client/lib/src/home/home_copy.dart` |

Rules kept: sentence case, a verb on every button, no exclamation marks, no invented numbers, no prices, no mention of paid courses, automatic grading or file uploads. Text in `{braces}` is filled in by the app.

## 1. Positioning

| Audience | One sentence | Main reason to care |
|---|---|---|
| Learners | Lectale opens a course and shows its lessons, PDFs, notebooks and video in one app. | Free to read, with no account. |
| Instructors | Lectale presents the course you already keep in a GitHub repository, and handles enrolment and grades for you. | You keep your files and your repository; nothing moves to us. |

## 2. Hooks

Each hero has a headline (8 words or fewer), a subheading (25 words or fewer) and two calls to action. Word counts are in brackets.

### Hook A: the action

- **Headline:** Open a course and start reading (6)
- **Subheading:** Lectale shows a course's lessons, PDFs, notebooks and video in one app. Free to read, no account needed. (18)
- **Primary:** Open a course (goes to the link field, section 5.1)
- **Secondary:** Browse courses

### Hook B: the instructor

- **Headline:** Teach from your own repository (5)
- **Subheading:** Keep your course files in GitHub. Lectale shows them to learners and handles enrolment and grades. (16)
- **Primary:** Create account
- **Secondary:** See how it works

### Hook C: the content

- **Headline:** Every kind of course in one reader (7)
- **Subheading:** Read text, PDFs, notebooks, video and audio in one app, on the web or on your device. No account needed. (22)
- **Primary:** Open a course
- **Secondary:** Download the app

### Hook D: the reading experience

- **Headline:** Courses that read like a good book (7)
- **Subheading:** Lectale opens a course as a clean, readable page, with its lessons, PDFs, notebooks and video together. Free to read, no account. (22)
- **Primary:** Open a course
- **Secondary:** Browse courses

### Hook E: one calm place

- **Headline:** One quiet place for the whole course (7)
- **Subheading:** Lectale gathers a course's text, PDFs, notebooks, video and audio in one app, so learners stop switching between tabs. (19)
- **Primary:** Open a course
- **Secondary:** See what you can read

### Hook F: ownership for instructors

- **Headline:** Your course stays yours (4)
- **Subheading:** Keep your course in your own GitHub repository. Lectale turns it into a place learners can read, enrol in and be graded. (22)
- **Primary:** Create account
- **Secondary:** See how it works

### Hook G: free and open

- **Headline:** Read the course. Skip the sign-up. (6)
- **Subheading:** Lectale opens courses in your browser or on your device. Lessons, PDFs, notebooks and video are free to read, with no account. (22)
- **Primary:** Open a course
- **Secondary:** Browse courses

### Hook H: the tabs (strongest)

- **Headline:** Open the course. Close the other tabs. (7)
- **Subheading:** Lectale shows a course's lessons, PDFs, notebooks, video and audio in one app. Free to read, no account needed. (19)
- **Primary:** Open a course
- **Secondary:** Browse courses

### Recommendation

Use **Hook H**. It replaces Hook A, which only gave an instruction.

Why H beats A for a first-time visitor who doesn't know GitHub:

- **It names a problem the visitor already has.** Anyone who has studied online has a PDF in one tab, a video in another and notes in a third. A reader recognises that in one second and does not need to know what a repository is.
- **It carries the promise, then the action.** "One place" is Lectale's distinctive claim; "Open the course" is the first step. A says only the step.
- **The subheading finishes the job.** It says plainly what Lectale is (an app that shows lessons, PDFs, notebooks, video and audio together) and answers the cost and sign-up objection. GitHub does not appear above the fold.
- **It is short, dry and a little warm.** There is no hype, and it does not read like generic software copy.

Runners-up: **D** has the most memorable promise, but "read like a good book" leans on the instructor's writing as much as on our design, so it can disappoint. **G** is the best choice if the owner wants the free, no-account point to lead. **F** is the best headline for an instructor-only page, for example the "For instructors" landing, and it is the only option that suits "Create account" as the primary action. Hook A and Hooks B and C stay for comparison.

Decision for the design lead: H's headline has two short sentences. Set them on two lines on wide screens, with the same size and weight, so the contrast reads at a glance.

## Hero, round 3

Ten new hooks after the owner asked for a stronger one that also sits well beside a visual of quotes about reading and learning. Headline 8 words or fewer, subheading 25 words or fewer (counts in brackets). Calls to action stay "Open a course" and "Browse courses" for all ten. Every subheading says what Lectale is in plain words and uses only facts in the spec: no prices, no claim about remembering a reading position.

### Options

1. **Keep your place in the course** (6)
   - Subheading: Lectale shows a course's lessons, PDFs, notebooks, video and audio in one reader. Save a course with an account; reading needs none. (22)
   - Angle: bookmark. Ties to the ribbon in the logo.
2. **Read a course like a book** (6)
   - Subheading: Lectale opens a course as one calm reader, with its lessons, PDFs, notebooks, video and audio in order. Free to read, no account. (23)
   - Angle: reading a course like a good book.
3. **Start at page one. Finish the course.** (7)
   - Subheading: Lectale shows a course's outline and every lesson in one reader, so you can read it in order. Free to read, no account needed. (24)
   - Angle: reading a course like a book, as a two-step arc.
4. **Give the course your whole attention** (6)
   - Subheading: Lectale shows lessons, PDFs, notebooks, video and audio in one quiet reader, with no ads and no tracking. (18)
   - Angle: attention and calm. "No ads, no tracking" is true per the privacy section.
5. **Nothing to find. Just the next lesson.** (7)
   - Subheading: Lectale puts a course's outline, lessons, PDFs, notebooks, video and audio in one reader. Pick a lesson and read. (19)
   - Angle: calm; one place instead of scattered material.
6. **Someone wrote a course on it** (6)
   - Subheading: Lectale opens courses that teachers publish on GitHub, and shows their lessons, PDFs, notebooks, video and audio in one reader. (20)
   - Angle: curiosity and learning anything. Needs real courses in the catalog to be honest at launch.
7. **A link is all a course needs** (7)
   - Subheading: Paste the link to a course on GitHub. Lectale shows its lessons, PDFs, notebooks, video and audio. No account needed. (20)
   - Angle: curiosity and openness; the link is the whole way in.
8. **Courses that belong to their teachers** (6)
   - Subheading: Teachers keep their course files in their own place on GitHub. Lectale lets anyone read them without an account. (19)
   - Angle: open, free, instructor-owned, with no jargon.
9. **Not a pile of files. A course.** (7)
   - Subheading: Lectale turns the course files a teacher keeps on GitHub into one course you can read, with lessons, PDFs, notebooks, video and audio. (23)
   - Angle: two-line contrast, and it names what Lectale does for the instructor's files.
10. **One course. One tab.** (4)
    - Subheading: Lectale shows a course's lessons, PDFs, notebooks, video and audio in one reader. Free to read, no account needed. (20)
    - Angle: two-line contrast, a shorter and more exact version of the current hero.

### Top three

1. **Read a course like a book** (option 2). It names something a reader can picture at once, where "Close the other tabs" only names a chore. It also fits a right-hand visual of quotes about reading, because the words and the picture say the same thing. The subheading grounds the promise in the reader, so it does not depend on the instructor's writing.
2. **Keep your place in the course** (option 1). It is the only hook that uses the ribbon, so the logo and the headline explain each other, and it promises something a tab pile cannot give. The line is true today only for saved courses (an account is needed). If Lectale will remember the lesson you stopped at, say so and make the headline stronger.
3. **Someone wrote a course on it** (option 6). It gives a visitor a small jolt of recognition ("there may be a course on the thing I want to learn") rather than a tip about tabs, and no other learning app could say it because Lectale opens courses that teachers publish. It is honest only if the catalog has real courses, or the example cards are clearly labelled; otherwise use option 7.

Call to action: keep "Open a course" for all three. If option 6 is chosen, the secondary "Browse courses" matters more, so keep it as a visible button, not a text link.

Why the current hero ranks below: "Open the course. Close the other tabs." is an instruction and a chore. It makes the visitor think about their own mess, not about what reading in Lectale is like.

## Hero, round 4: from the platform's strengths (orchestrator, 2026-11-22)

The owner called rounds 1 to 3 "mid" and asked for hooks built on what makes the platform worth using, especially how easy it is to create, find and learn from courses. The strengths, from the spec:

1. **A course is a folder.** Lessons, PDFs and notebooks in a GitHub repository plus one outline file, `course.yaml`, are the whole course. No upload, no lock-in; the author keeps the content, its history and the freedom to leave (DEC-08).
2. **Publishing is sharing a link.** Any public repository with `course.yaml` opens in Lectale by its link; neither author nor reader needs an account (V4-CORE-01, V4-CORE-02).
3. **Learning is free and frictionless.** No sign-up, no tracking, no paywall to read (V4-COST-06).
4. **One reader for everything**, on web, desktop and Android.
5. **Courses don't shift under you.** A course is read at a fixed commit (pinned SHA).
6. **Courses are findable** in the opt-in catalog (V4-CAT-01).

The hook should carry 1 and 2, the two-sided ease, and let the subheading carry 3.

| Option | Headline | Subheading |
|---|---|---|
| **R4-A (recommended)** | Teach from a folder. Learn from a link. | Put your lessons, PDFs and notebooks in a GitHub repository, add one outline file, and share a link. Anyone can read it free, no account. |
| R4-B | Any folder can be a course. | Put lessons, PDFs and notebooks in a GitHub repository with one outline file. Lectale turns it into a course anyone can read free. |
| R4-C | Publish a course with one file. | Add `course.yaml` to a GitHub repository of lessons, PDFs and notebooks, and share the link. Lectale shows it as a course, free to read. |
| R4-D | Free courses, straight from the people who teach them. | Teachers keep their courses on GitHub. Lectale lets you find them and read lessons, PDFs, notebooks and video in one place, without an account. |
| R4-E | Write it on GitHub. Teach it anywhere. | Your repository becomes a course on the web, desktop and Android. Learners read it free; you keep every file and every change. |

Calls to action with R4-A: **Find a course** (primary, gold, to the catalog with the link field above it) and **Make a course** (secondary, to the instructors section and its guide).

### Chosen hero (owner, 2026-11-22)

- **Headline:** Your course, online in minutes.
- **Subheading:** Put your lessons, PDFs and notebooks in a GitHub repository, add one outline file, and share a link. Anyone can read it free, no account.
- **Calls to action:** Make a course (primary, gold) and Find a course (secondary). The headline speaks to teachers, so making a course leads; finding one stays one click away.
- **Why:** the owner judged earlier headlines as describing the product without convincing anyone. This one leads with the outcome a teacher wants, and the subheading shows why it is quick.

## 3. Navigation labels

| Place | Label | Note |
|---|---|---|
| Brand | Lectale | Logo and wordmark; the link goes to the top of the page. Accessible name: "Lectale, home". |
| Link | Catalog | |
| Link | Download | |
| Link | For instructors | Plain and already clear. "For teachers" is wrong for university staff; keep this. |
| Link | Log in | Text link, not a button. |
| Button | Create account | |

**Primary call to action in the header: Create account.** It is the one action in the header that does something the page body does not. The hero already carries "Open a course", so the design lead should give the gold accent to one of the two in any one view, and I suggest the hero button; the header button then uses a plain outlined style.

Small screens: Catalog, Download and For instructors move into a menu button named "Menu". Log in and Create account stay visible.

## 4. Sections, in order

### 4.1 What you can read

- **Heading:** Everything in the course opens in the app
- **Intro:** Learners don't need to download files or visit GitHub to read a lesson.

| Title | Text |
|---|---|
| Text | Lessons and course descriptions, as formatted pages. |
| PDFs | Read slides and handouts without downloading them. |
| Notebooks | A notebook is a document that mixes text, code and results. Lectale shows it. It does not run the code. |
| Video | Watch lecture recordings. A video from another website asks your permission before it loads. |
| Audio | Listen to recordings and read along. |
| Code | Read code and data files as plain text. |

- **Closing line:** Any other file shows its name and size, with a safe download.

### 4.2 How it works for learners

- **Heading:** How to start

| Step | Title | Text |
|---|---|---|
| 1 | Find a course | Paste a course link, or choose a course from the catalog. |
| 2 | Read it | Lectale shows the description, the outline and each lesson. |
| 3 | Add an account when you need one | Create an account to enrol in a course or save it for later. Reading never needs one. |

- **Link under the steps:** Open a course (to the link field)

### 4.3 For instructors

- **Heading:** Keep your course. Lectale presents it.
- **Body:** Your course stays in a GitHub repository that you own. Lectale reads it and turns it into a course that learners open in the app.

**What you keep**

- Your files and your repository.
- Your choice of whether the course appears in the catalog. A new course starts unlisted.

**What you get**

- A course page built from your README and your outline.
- Enrolment: open, by approval or by invitation.
- Grades, kept in one place.

- **Button:** Create account
- **Link:** Open a course by link (for instructors who want to see their repository in the app first; no account needed)

### 4.4 Catalog teaser

- **Heading:** Browse listed courses
- **Body:** Instructors choose to list a course. Everything else can still be opened by its link.
- **Link:** Browse the catalog

Three example cards. Each carries the tag **Example course** and the author line **Example instructor**, so none reads as a real person's work. Thumbnails: abstract covers, not photos of people.

| Card | Title | Summary | Details |
|---|---|---|---|
| 1 | Introduction to statistics | Describe data, read charts and test simple ideas. | English · Example course |
| 2 | Reading medieval manuscripts | Learn to date and transcribe handwriting from scanned pages. | English · Example course |
| 3 | Python for lab data | Clean, plot and share measurements in notebooks. | English · Example course |

- **Note under the cards:** These are examples. They are not real courses.
- **Card accessible name:** "{title}, example course"

### 4.5 Downloads

- **Heading:** Use Lectale on your device
- **Intro:** Use it in your browser, or install it.

| Platform | Button | Text |
|---|---|---|
| Web | Open in browser | Works on any device with a current browser. Nothing to install. |
| Android | Download for Android | An APK file from GitHub Releases. Your phone may ask you to allow installing from your browser. |
| Windows | Download for Windows | From GitHub Releases. |
| macOS | Download for macOS | From GitHub Releases. |
| Linux | Download for Linux | From GitHub Releases. |

- **iPhone and iPad:** Lectale has no iPhone or iPad app. Open it in Safari or another browser instead.
- **QR caption:** Scan with your phone to open Lectale.
- **QR text alternative:** QR code that opens Lectale in your phone's browser. The same link is under "Open in browser".

### 4.6 Privacy

- **Heading:** No tracking
- **Text:** Lectale has no analytics, advertising or trackers. Opening a course by link reads public repositories only.
- **Link:** Read the privacy notice

### 4.7 Footer

- **Brand line:** Lectale
- **Description:** Open and read courses from GitHub repositories.
- **Links:** Catalog, Download, For instructors, Privacy notice, Terms, Accessibility
- **Independence line:** Lectale is an independent project and is not affiliated with GitHub.
- **Legal line:** © 2026 {operator name}

## 5. Small copy

### 5.1 Open a course by link

Reused unchanged from `home_copy.dart`.

| Element | Text |
|---|---|
| Title | Open a course from GitHub |
| Help | Any public GitHub repository with a course.yaml file. No account needed; Lectale only reads it. |
| Label | GitHub repository address |
| Hint | For example, https://github.com/owner/repository |
| Button | Open course |
| Progress | Reading the repository |
| Empty address | Enter the address of a GitHub repository. |
| Malformed | That doesn't look like a GitHub repository address. Use the form https://github.com/owner/repository. |
| Other host | Lectale opens repositories on github.com. Use the form https://github.com/owner/repository. |

The other failure texts in `home_copy.dart` stay as they are, except the one in the question list below.

### 5.2 Catalog, empty and failed

| State | Title | Text | Button |
|---|---|---|---|
| Empty | No courses are listed yet | Instructors choose to list their courses here. You can still open any public course with its link. | Open a course |
| Failed | We could not load the catalog | Check your connection and try again. You can still open a course with its link. | Try again |
| No search results | No courses match "{search}" | Check the spelling or search with fewer words. | Clear search |

### 5.3 Log in

- **Title:** Log in
- **Fields:** Email; Password (with a "Show password" toggle)
- **Button:** Log in
- **Link under the button:** Forgot your password?
- **Link to the other screen:** No account yet? Create account
- **Wrong email or password (the same text for an unknown email and a wrong password):** The email or password is not correct. Check both and try again, or reset your password.
- **Too many attempts:** Too many attempts. Wait a few minutes, then try again.
- **Correct password, email not confirmed yet:** Confirm your email first. We sent you a link when you created the account. Button: Send the link again
- **Empty field:** Enter your email. / Enter your password.

### 5.4 Create account

- **Title:** Create your account
- **Line under the title:** You need an account to teach, enrol or save courses. You don't need one to read.
- **Fields:** Email; Password. Password hint: Use at least 12 characters. A password you don't use anywhere else is best.
- **Button:** Create account
- **Consent line (no tick box needed, because it is not optional consent):** By creating an account you accept the Terms and the Privacy notice. (Both are links.)
- **Link to the other screen:** Already have an account? Log in
- **After submitting, shown for every email, new or already used:** Check your email. If {email} can be used for a new account, we have sent a link to confirm it. If you already have an account, log in or reset your password.
- **Invalid email format:** Enter an email like name@example.com.

### 5.5 Reset password

- **Title:** Reset your password
- **Field:** Email
- **Button:** Send reset link
- **After submitting, always:** If an account uses {email}, we have sent a link to reset the password. It may take a few minutes. Check your spam folder too.
- **Link:** Back to log in

### 5.6 Signed-in home

- **Greeting:** Hello, {first name}. Without a name: Hello.
- **Section heading:** Your courses
- **Empty state, title:** You have no courses yet
- **Empty state, text:** Open a course with its link, or browse the catalog.
- **Buttons:** Open a course (primary); Browse the catalog
- **Instructor line, once managed courses ship:** Teaching a course? Connect its repository to manage it. Link: Connect a repository

## 6. Questions for the design lead and owner

1. **Where does the QR code point?** I wrote the caption for the web app. If it points to the Android APK instead, change the caption to "Scan to download Lectale for Android" and the alternative text to match. Pick one; two codes would add clutter.
2. **Grades without uploads.** The brief asks for grading under instructors, but file uploads stay unmentioned. "Grades, kept in one place" is true for manual grading, yet an instructor may ask "grades for what?". Keep the line, or drop it until hand-in exists.
3. **Private-repository error.** The current alert says "Repository not available ... A private repository can't be opened here." It is identical for both cases, so it passes, but it offers no owner sign-in route, which the spec requires. Proposed replacement, same for every case: title "We could not open this course"; body "Check that the link is correct and that the repository is public. If you own it, sign in to connect it."; action "Log in". This changes `home_copy.dart`, which I was told to reuse, so I did not edit it.
4. **Create-account confirmation.** The "Check your email" text only stays enumeration-safe if the flow sends a verification link. The security reviewer should confirm that Firebase Auth is set up that way, or the text must change.
5. **Sign-in methods.** I assumed email and password. If sign-in with GitHub or Google is offered, buttons need the same verb pattern ("Continue with GitHub") and I will write them.
6. **Pages the copy links to must exist:** Privacy notice, Terms, Accessibility. The legal line needs the operator's name (spec: human input).
7. **Android install note.** "Your phone may ask you to allow installing from your browser" is accurate for APKs outside a store, but check it on a real device before launch.
8. **Header call to action.** Create account is primary in the header; see section 3 for the gold accent suggestion.

## 7. Changes from the security review

Applied on 2026-11-21 from `docs/security/reviews/2026-11-21-auth-and-landing-requirements.md` (A6): the create-account confirmation no longer implies a link was sent for an existing email; "a few minutes" for the lockout, since Firebase publishes no time; a new state for an unconfirmed email; the 12-character password hint. The "Log in" action on the private-or-missing message is approved if it appears for every cause (R23), and becomes "Connect a repository" for a signed-in visitor.
