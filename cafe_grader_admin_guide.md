# Cafe-Grader Administrator Guide

This guide is for users with the `admin` or `ta` role in the Cafe-Grader system. It explains how to manage the platform, users, and content.

---

## 1. User Management
The User Admin section allows you to manage who can access the grader.

### Adding Users
- **Individually**: Navigate to `Admin -> User Admin` and click "New User".
- **Bulk Import (CSV)**: 
  - Go to `Admin -> User Admin -> Create from List`.
  - You can paste a list of users or upload a CSV file.
  - The system can automatically generate random passwords for new users.
- **Contest-Specific**: Inside a specific Contest's management page, you can add users specifically to that contest.

### Permissions & Activation
- **Enable/Disable**: You can temporarily disable a user account without deleting it.
- **Roles**: Assign roles like `admin`, `ta`, or `group_editor`.
- **Clear IP**: If a user is locked to a specific IP (Contest Mode), you can clear their last known IP to let them log in from a new machine.

---

## 2. Problem & Dataset Management
Problems are the core coding tasks. Each problem can have multiple **Datasets**, but only one is "Live" (used for scoring).

### Creating Problems
1. Go to `Admin -> Problems -> Quick Create`.
2. Upload the **Statement** (PDF or HTML).
3. Create a **Dataset**.
4. **Import Testcases**: Upload a ZIP file containing `.in` and `.sol` files (e.g., `1.in`, `1.sol`).
5. Set the weights for each testcase.
6. Click **"Set as Live"** to make this version of the problem active.

### Rejudging
If you find an error in your testcases or a student's submission was graded incorrectly, you can use the **Rejudge** button on a specific submission or an entire problem.

---

## 3. Contest Management
Cafe-Grader supports different system-wide modes.

### System Modes
- **Standard Mode**: Typical for classroom use where students see all available problems.
- **Contest Mode**: Used for time-bound exams. Students only see problems assigned to the active contest and may have restricted features (like limited score viewing).
- **Indv-Contest**: Allows each student to have their own individual start/end time.

### Managing Contests
- Assign specific **Problems** and **Users** to a contest.
- Set **Extra Time** for specific students if needed.
- Monitor the **Contest View** to see real-time scores of all participants.

---

## 4. Reports & Security
Admin roles have access to several powerful reporting tools:

- **Max Score Report**: A spreadsheet-style view of all users' highest scores across all problems.
- **Cheat Report**: A plagiarism detection tool that compares code submissions to find similarities between students.
- **Login Report**: Detects if multiple users are logging in from the same IP address or if one user is using multiple machines.
- **Audit Logs**: A complete history of who changed what in the admin panel (e.g., who changed a testcase or edited a score).

---

## 5. System Configuration
Located under `Admin -> Grader Configuration`.

- **Site Settings**: Change the "Site Name", "Welcome Message", and "Theme".
- **Grading Queue**: View the status of the background grading processes. If the grader gets stuck, you can "Retry" error jobs from here.
- **Announcements**: Create site-wide messages that appear on the login page or the user's dashboard.

---

## 6. Communication
- **Messages**: A built-in ticketing system. Students can send messages to admins, and admins can reply.
- **Announcements**: Use this for important updates (e.g., "The contest will end 10 minutes later").

---

## Tips for Local Testing
1. **Mock Submissions**: You can log in as a student (or use "Direct Edit" in the admin panel) to submit code for testing.
2. **Database Seeds**: If you accidentally delete data while testing, you can reset everything by running `bin/rails db:seed`.
