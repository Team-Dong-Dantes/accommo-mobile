// The Terms of Service and Privacy Notice, shipped with the app.
//
// These are NOT OSAS content and deliberately do not live in the `policies`
// table: they are the agreement between a user and Accommo, so an administrator
// must not be able to rewrite what people have already accepted, and the
// register screen must never be able to render an empty consent dialog because a
// row is missing, archived, or unreachable. OSAS policies, guidelines and house
// rules are the editable ones and stay in the database.
//
// ─────────────────────────────────────────────────────────────────────────────
// DRAFT — must be reviewed by OSAS and by the university's legal counsel or Data
// Protection Officer before release. This text was written to match what the app
// actually collects and does, and it cites the statutes it rests on, but citing
// a law is not the same as a lawyer confirming the document complies with it.
// It is a starting point, not legal advice, and the commitments below are the
// university's to make, not the developers'.
// ─────────────────────────────────────────────────────────────────────────────
//
// TO REVISE A DOCUMENT: edit the body AND bump that document's `effectiveDate`.
// The dates are per-document and each drives its own consent independently —
// TermsGate compares each against the matching column on `users` and asks again
// only for the one that moved. Editing a body without moving its date changes
// what new users see while leaving everyone who already accepted on the old
// version, which is only correct for fixing a typo. Because these documents ship
// inside the APK, a revision reaches users through a release: bump the version,
// ship it, and raise `min_supported_version_code` if nobody should stay on the
// previous version.

export type LegalDocumentId = 'terms' | 'privacy';

export type LegalDocument = {
  id: LegalDocumentId;
  title: string;
  /** The consent column on `public.users` that records acceptance of this one. */
  acceptedColumn: 'terms_accepted_at' | 'privacy_accepted_at';
  effectiveDate: string; // ISO date
  body: string;
};

const TERMS: LegalDocument = {
  id: 'terms',
  title: 'Terms of Service',
  acceptedColumn: 'terms_accepted_at',
  effectiveDate: '2026-09-14',
  body: `1. About these terms

Accommo is a student accommodation platform operated for the Isabela State University community through the Office of Student Affairs and Services (OSAS). By ticking the box on the registration screen you agree to these terms. If you do not agree, do not create an account.

Accepting electronically is binding. Under the Electronic Commerce Act of 2000 (Republic Act No. 8792), an agreement is not denied legal effect merely because it was entered into through an electronic data message.

2. Who may use Accommo

You may register as a student if you are currently enrolled at the university, or as a landlord/landlady if you own or manage boarding accommodation offered to its students. You must give accurate information when you register and keep it up to date. One person may hold one account.

3. What Accommo does, and what it does not do

Accommo lists accommodations, lets students apply to them, and gives students and landlords/landladies a place to message each other and keep a record of their arrangement.

Accommo is not a party to your lease. An agreement to rent is made between the student and the landlord/landlady, and is governed by the lease provisions of the Civil Code of the Philippines (Republic Act No. 386, Articles 1642 to 1688) and, where the unit and the rent fall within its coverage, by the Rent Control Act of 2009 (Republic Act No. 9653) as extended. Nothing in these terms removes a right either party has under those laws.

The university and OSAS do not own, operate, inspect for habitability, insure, or guarantee any accommodation listed here, and are not responsible for the conduct of any student or manager. Listing an accommodation is not an endorsement of it.

4. Your account

You are responsible for what happens under your account. Keep your password and your app PIN to yourself. Tell us immediately if you believe someone else has access to your account. Gaining access to another person's account without permission is an offence under the Cybercrime Prevention Act of 2012 (Republic Act No. 10175).

5. Verification

Students and landlords/landladies may be asked to submit documents to OSAS so their identity, enrolment, or ownership of an accommodation can be verified. Submitting a document that is forged, altered, or belongs to someone else is grounds for immediate removal and may be referred for disciplinary or legal action.

6. Listings and fair dealing

A landlord/landlady must describe a property accurately — its rooms, rent, deposits, facilities and house rules. Misleading descriptions of what is being offered may engage the Consumer Act of the Philippines (Republic Act No. 7394) as well as these terms.

7. Payments

Payments recorded in Accommo are a record of an arrangement between a student and a manager. Accommo does not collect, hold, process, or transfer money. A payment marked paid in the app reflects what the landlord/landlady confirmed; it is not a receipt issued by the university. Disputes about money are between the student and the landlord/landlady, though OSAS may be asked to mediate.

8. Ratings and conduct

Ratings and their comments must describe your own genuine experience. Do not post anything false, abusive, discriminatory, threatening, or that reveals another person's private information. Do not use Accommo to harass anyone, to advertise unrelated goods or services, or to collect other users' data.

Harassment through this app is not only a breach of these terms. Gender-based online sexual harassment is punishable under the Safe Spaces Act (Republic Act No. 11313); sexual harassment in an education or training institution is covered by Republic Act No. 7877; and taking, copying or sharing a photo or video of a person in a private setting without their consent is an offence under the Anti-Photo and Video Voyeurism Act of 2009 (Republic Act No. 9995), which applies to images sent through the messaging in this app.

You are also bound by the university's student handbook and by OSAS regulations, which are published separately in the app under Settings.

We may remove content that breaks these rules.

9. Suspension and removal

OSAS may suspend or remove an account that breaks these terms, that misrepresents an accommodation, or that puts other users at risk. Where it is reasonable to do so you will be told why, and you may respond through the support channel in the app.

10. Availability

Accommo is provided as it is. We try to keep it working and accurate, but we do not promise it will always be available or free of errors, and we are not liable for loss arising from your use of it except where the law does not allow that limitation.

11. Governing law

These terms are governed by the laws of the Republic of the Philippines. Disputes that cannot be settled through OSAS are subject to the appropriate courts of Isabela.

12. Changes to these terms

We may update these terms. When we do, the effective date changes and you will be asked to read and accept the new version before continuing to use the app.

13. Contact

Questions about these terms go to OSAS through the support section of the app.`,
};

const PRIVACY: LegalDocument = {
  id: 'privacy',
  title: 'Privacy Notice',
  acceptedColumn: 'privacy_accepted_at',
  effectiveDate: '2026-09-14',
  body: `This notice explains what personal information Accommo collects, why, who can see it, and what you can do about it. It is written to meet the Data Privacy Act of 2012 (Republic Act No. 10173), its Implementing Rules and Regulations, and the issuances of the National Privacy Commission.

You are asked to consent to this notice separately from accepting the Terms of Service, because consent to the processing of your personal information is its own decision and you are entitled to make it on its own.

1. Who is responsible

The Isabela State University, through the Office of Student Affairs and Services, decides how your information is used in Accommo and is the personal information controller for it under Republic Act No. 10173.

2. What we collect

Account details: your name, email address, mobile number, sex, and profile photo.

Student details: your college, programme, and year level.

Verification documents: identification, proof of enrolment, and — for landlords/landladies — documents showing ownership or authority over a property. These are reviewed by OSAS staff.

Accommodation and tenancy records: listings, applications, leases, room assignments, move-in and move-out records, and your stay history.

Payment records: amounts, dates, methods, and whether a landlord/landlady confirmed a payment. We do not collect card or bank account numbers.

Messages: conversations between you and other users, including photos you send.

Location: the approximate location of accommodations, and your device's location only while you are using the map to search, and only if you allow it. You can refuse and still use the rest of the app.

Technical information: sign-in times and basic device information needed to keep the app working and secure.

3. Why we use it, and on what basis

To create and verify your account. To show you accommodations and let you apply. To let landlords/landladies assess applications and manage their tenants. To keep a record of leases and payments. To let you message the people you are dealing with. To handle concerns and support tickets. To keep the platform safe, investigate reports of misuse, and meet the university's own obligations.

Under Section 12 of Republic Act No. 10173 we rely on your consent, on the necessity of processing to carry out the arrangement you enter into, and on the legitimate interests of the university in running a safe housing service for its students. Sensitive personal information, which includes your sex and any government identification you submit, is processed on the basis of your consent under Section 13.

4. Who can see your information

Landlords/Landladies see the profile and application details of students who apply to them, and the records of their own tenants.

Students see a landlord/landlady's listing and public profile details.

OSAS and university administrators see what they need in order to verify accounts, review documents, respond to concerns, and audit activity on the platform.

Other users see only what a screen is designed to show them — never your verification documents.

Service providers that host and run the app on our behalf process data under our instructions as personal information processors: Supabase (database and authentication), Cloudinary (image storage), Mapbox (maps), and Google (if you choose to sign in with a Google account). Some of them store data outside the Philippines; the university remains accountable for it under Republic Act No. 10173.

We do not sell your personal information and we do not use it for advertising.

5. How long we keep it

Account and tenancy records are kept while your account is active and afterwards for as long as the university needs them for its records, for resolving disputes, and for meeting its legal obligations. Verification documents are kept only as long as needed to verify you and to answer any later question about that verification. Messages are kept while the conversation exists.

6. Your rights

Under Chapter IV of Republic Act No. 10173 you have the right to be informed, to object to processing, to access the personal information we hold about you, to have it corrected, to have it erased or blocked where the law allows, to be indemnified for damage caused by its misuse, and to data portability.

To exercise any of these, contact OSAS through the support section of the app. If you are not satisfied with our response, you may complain to the National Privacy Commission.

7. Keeping it safe

Access is restricted by role, so people see only the records their role requires. Data is transmitted over encrypted connections. You can add a PIN to protect sensitive screens on your device. Unauthorised access to this data is an offence under the Cybercrime Prevention Act of 2012 (Republic Act No. 10175).

No system is perfectly secure. If a breach is likely to give rise to a real risk to your rights, we will notify you and the National Privacy Commission within the period required by Republic Act No. 10173 and its Implementing Rules.

8. Images and messages

Photos you send through the app are personal information and may also be protected by the Anti-Photo and Video Voyeurism Act of 2009 (Republic Act No. 9995). Do not send images of another person without their consent, and do not copy or share images sent to you.

9. Children

Accommo is for university students and landlords/landladies. It is not intended for children under 18. A student under 18 should have a parent or guardian review these documents, whose consent is required for processing under Republic Act No. 10173.

10. Changes to this notice

If we change this notice, the effective date changes and you will be asked to read and accept the new version before continuing to use the app.

11. Contact

Reach OSAS through the support section of the app, or contact the university's Data Protection Officer for matters concerning your personal information.`,
};

/** Order matters: the Terms are read first. */
export const LEGAL_DOCUMENTS: LegalDocument[] = [TERMS, PRIVACY];

/**
 * Each document's effective date, keyed by id — derived from the documents
 * rather than hand-maintained so it cannot drift from the text. `TermsGate`
 * compares each against the matching column on `public.users`, so revising one
 * document never re-asks for the other.
 */
export const LEGAL_EFFECTIVE_DATES = Object.fromEntries(
  LEGAL_DOCUMENTS.map((doc) => [doc.id, doc.effectiveDate]),
) as Record<LegalDocumentId, string>;
