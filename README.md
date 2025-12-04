# AWS Serverless Email Service (Terraform)

This project deploys a scalable, event-driven email sending architecture on AWS using Terraform. It decouples the application from the email provider by using an SQS queue as a buffer, ensuring high availability and fault tolerance.

## 🏗 Architecture

1.  **Templates (S3):** Stores HTML email templates.
2.  **Buffer (SQS):** Receives email requests from your applications. Includes a Dead Letter Queue (DLQ) for retries.
3.  **Processor (Lambda):** Triggered by SQS. It:
      * Parses the message.
      * Fetches the HTML template from S3.
      * Replaces variables (e.g., `{{name}}`).
      * Sends the email via SES.
4.  **Delivery (SES):** Handles the actual email transmission.

-----

## ✅ Prerequisites

Before deploying, ensure you have the following installed:

  * **[Terraform](https://www.terraform.io/downloads)** (v1.0+)
  * **[AWS CLI](https://aws.amazon.com/cli/)** (Configured with `aws configure`)
  * **[Node.js](https://nodejs.org/)** (v18 or v20) - Required to compile the TypeScript Lambda.

### Critical AWS Setup

**Amazon SES Sandbox:**
If your AWS account is new, it is in the "SES Sandbox." You must verify **both** the sender email AND the recipient email in the [AWS SES Console](https://console.aws.amazon.com/ses/home) before you can send emails.

-----

## 📂 Project Structure

```text
.
├── lambda/
│   ├── src/index.ts      # TypeScript logic for email processing
│   ├── dist/             # Compiled JavaScript (Generated automatically)
│   ├── package.json      # Node.js dependencies
│   └── tsconfig.json     # TypeScript configuration
├── main.tf               # Infrastructure definition (S3, SQS, Lambda, IAM)
├── variables.tf          # Configurable variables
├── outputs.tf            # Output values (Queue URL, Bucket Name)
└── README.md             # Documentation
```

-----

## 🚀 Deployment

### 1\. Initialize Terraform

Download the necessary providers.

```bash
terraform init
```

### 2\. Plan & Apply

Deploy the infrastructure. Terraform will automatically run `npm install` and `npm run build` for the Lambda function.

**Important:** Change the `project_name` to something unique to avoid S3 naming conflicts.

```bash
terraform apply \
  -var="project_name=my-email-service-v1" \
  -var="environment=dev" \
  -var="sender_email=verified-sender@example.com"
```

Type `yes` when prompted.

-----

## 🧪 How to Test

Once deployed, Terraform will output the `queue_url`. You can send a test JSON message to this queue to trigger an email.

### 1\. The Payload Format

Your application should send messages to SQS in this format:

```json
{
  "to": "recipient@example.com",
  "subject": "Welcome to our Platform",
  "template_key": "welcome.html",
  "data": {
    "name": "Developer"
  }
}
```

### 2\. Test via AWS CLI

Replace `<QUEUE_URL>` with the output from Terraform and `<RECIPIENT>` with a verified email.

```bash
aws sqs send-message \
    --queue-url <QUEUE_URL> \
    --message-body '{"to": "verified-recipient@example.com", "subject": "Test Email", "template_key": "welcome.html", "data": {"name": "Friend"}}'
```

### 3\. Verify

  * Check the recipient inbox.
  * Check CloudWatch Logs for the Lambda function (`/aws/lambda/my-email-service-v1-dev-email-processor`) if the email doesn't arrive.

-----

## ⚙️ Configuration Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `aws_region` | AWS Region to deploy to. | `us-east-1` |
| `project_name` | Unique name for the project (used for S3 naming). | **Required** |
| `environment` | `dev` or `prod`. Controls S3 deletion safety. | `dev` |
| `sender_email` | The "From" address. Must be verified in SES. | **Required** |

-----

## 🛡 Security & Best Practices

  * **S3 Protection:** \* In `dev`, `force_destroy` is enabled (running destroy deletes the bucket even if it has files).
      * In `prod`, the bucket cannot be destroyed if it contains data.
  * **Least Privilege:** The Lambda function has a strictly scoped IAM role allowing access *only* to the specific S3 bucket and SQS queue created by this project.
  * **DLQ:** Failed emails (e.g., bad template key, SES down) are moved to a Dead Letter Queue after 3 attempts.

-----

## 🧹 Cleanup

To remove all resources and stop paying for them:

```bash
terraform destroy \
  -var="project_name=my-email-service-v1" \
  -var="environment=dev" \
  -var="sender_email=..."
```
