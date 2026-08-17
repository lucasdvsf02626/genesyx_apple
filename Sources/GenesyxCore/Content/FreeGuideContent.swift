import Foundation

/// Accessible text equivalent of the bundled `7-Day Fertility Nutrition Starter Guide` PDF.
///
/// The PDF is not accessibility-tagged. A VoiceOver user therefore gets an unnavigable image of a
/// document, and `.accessibilityLabel` on the reader names that image without making it readable.
/// This is the text equivalent that closes that gap: the same words, structured as real headings
/// and lists so VoiceOver can move through them by rotor and Dynamic Type can resize them.
///
/// Transcribed from the PDF's own text layer, with three deliberate departures. Each one is a case
/// where reproducing the layer faithfully would produce a *worse* experience than the printed page,
/// which is the opposite of what an equivalent is for:
///
/// 1. **The running footer is dropped.** Every page carries a letter-spaced `FOODS FOR FERTILITY`
///    device, which the text layer stores as `FO O D S FO R F E RT I L I TY`. A screen reader
///    voices that as individual letters, twenty times over. It is decoration, not content.
/// 2. **Page 18's shopping list is re-grouped.** `Sweet Potatoes` and `Avocados` sit in the
///    fourth column of the *Fruit & vegetables* block on the page, but the text layer emits them
///    after the footer, at the very end. They are restored to the group they are printed under.
/// 3. **Page 20's closing line is rewritten.** The printed line reads *"Download out free app now
///    for ongoing personalised fertility support"* — which carries a typo, and asks a reader who
///    is already inside the app to go and download the app. The accompanying QR code points to
///    the website, which is the silent exit to Safari the reader deliberately blocks.
///
/// Departures 1 and 3 are corrections the printed PDF still needs. They are tracked as blockers 2
/// and 3 in `docs/HANDOFF.md` §0h and require a re-export from the designer's Affinity source; the
/// brief is `docs/FREE_GUIDE_DESIGNER_BRIEF.md`. Until that lands, the text version and the PDF
/// differ on page 20 **on purpose** — the text version is the correct one.
///
/// Like the PDF, this content has not yet had medical/content review. It introduces no claim the
/// PDF does not already make, so it does not widen that gap, but it travels through the same
/// review when the guide is signed off.
public enum FreeGuideContent {

    public static let title = "7-Day Fertility Nutrition Starter Guide"

    /// A run of content within a page. Modelled on what a screen reader needs to distinguish, not
    /// on how the page is laid out.
    public enum Block: Hashable, Sendable {
        /// Body copy.
        case paragraph(String)
        /// A sub-heading within the page, exposed to VoiceOver as a heading.
        case subheading(String)
        /// A bulleted list. Kept as a list rather than joined into a sentence so the rotor can
        /// step through it.
        case bullets([String])
    }

    public struct Page: Hashable, Sendable, Identifiable {
        /// Matches the printed page number, so a sighted person and a VoiceOver user can refer to
        /// the same place in the same document.
        public let number: Int
        public let heading: String
        public let blocks: [Block]

        public var id: Int { number }

        public init(number: Int, heading: String, blocks: [Block]) {
            self.number = number
            self.heading = heading
            self.blocks = blocks
        }
    }

    public static let pages: [Page] = [
        Page(number: 1, heading: "Your 7-Day Fertility Nutrition Starter Guide", blocks: [
            .paragraph("Simple food and lifestyle habits to help you feel more prepared for the pre-conception journey."),
            .paragraph("2026"),
        ]),

        Page(number: 2, heading: "Welcome", blocks: [
            .paragraph("If you’re preparing for pregnancy, it can be hard to know where to start. There is so much advice online, and a lot of it feels overwhelming, restrictive, or unrealistic. This guide is here to make things simpler."),
            .paragraph("Inside, you’ll find a gentle introduction to fertility-friendly nutrition, along with a practical 7-day plan to help you take a few positive first steps."),
            .paragraph("This is not about being perfect. It is about building supportive habits, eating well most of the time, and feeling a little more prepared."),
            .paragraph("Over the next few pages, we'll focus on simple things that can help:"),
            .bullets([
                "Eating regularly.",
                "Building balanced meals.",
                "Including more nutrient-rich foods.",
                "Supporting steady energy.",
                "Making small habits feel realistic.",
            ]),
            .paragraph("Think of this as a starting point — a calm, supportive guide to help you begin."),
        ]),

        Page(number: 3, heading: "A gentle note before you begin", blocks: [
            .paragraph("This guide is for general information only and should not replace personalised advice from your doctor, midwife, fertility team, or dietitian."),
            .paragraph("Fertility is influenced by many factors, and no diet or lifestyle approach can guarantee pregnancy."),
            .paragraph("Instead, think of this ebook as a helpful starting point — a simple way to begin building supportive habits before pregnancy."),
            .paragraph("If you have a medical condition, irregular periods, PCOS, endometriosis, thyroid concerns, or you are already under fertility care, it is always best to seek personalised advice alongside any changes you make."),
        ]),

        Page(number: 4, heading: "Why nutrition matters before pregnancy", blocks: [
            .paragraph("Food is not the only part of the picture, but it can be a helpful place to begin."),
            .paragraph("Eating well before pregnancy can support your overall health, energy levels, and nutritional intake, while helping you build a stronger foundation for the months ahead."),
            .paragraph("Rather than focusing on one “perfect” food, it is more helpful to think about your overall pattern of eating."),
            .paragraph("A simple, balanced approach often works best. That might include:"),
            .bullets([
                "Regular meals.",
                "Plenty of fruit and vegetables.",
                "Protein with meals.",
                "Higher-fibre carbohydrates.",
                "Healthy fats.",
                "Enough water.",
                "Fewer highly processed foods as everyday staples.",
            ]),
            .paragraph("Small, consistent steps really do add up."),
        ]),

        Page(number: 5, heading: "Hormones and fertility: keeping things steady", blocks: [
            .paragraph("Hormones play an important role in the menstrual cycle, ovulation, and overall reproductive health."),
            .paragraph("While food is only one part of the picture, everyday habits such as eating regularly, including enough protein, choosing higher-fibre foods, and getting enough sleep can help support a steadier routine overall."),
            .paragraph("This is one reason balanced meals can be so helpful. They may help support more even energy levels and make it easier to stay consistent with your habits."),
            .paragraph("Stress, poor sleep, constant energy dips, and an all-or-nothing approach to eating can all make things feel harder than they need to be."),
            .paragraph("You do not need to eat perfectly to support your body well. Small, regular habits can make a meaningful difference over time."),
        ]),

        Page(number: 6, heading: "Gut health: a simple part of the bigger picture", blocks: [
            .paragraph("Gut health has become a popular topic, and while it is not something to overcomplicate, it can be a helpful part of overall wellbeing."),
            .paragraph("A balanced diet that includes plenty of fibre-rich plant foods can support digestion and general health. Foods like fruit, vegetables, oats, beans, lentils, nuts, seeds, and live yoghurt can all be useful additions to a balanced routine."),
            .paragraph("Rather than focusing on specific “gut health” rules, it is often most helpful to keep things simple:"),
            .bullets([
                "Eat a variety of plant foods.",
                "Drink enough water.",
                "Include fibre regularly.",
                "Limit overly processed foods where you can.",
            ]),
            .paragraph("Again, this is not about perfection. It is about building supportive habits that work in real life."),
        ]),

        Page(number: 7, heading: "Simple food principles", blocks: [
            .paragraph("You do not need a strict plan to make a positive start."),
            .paragraph("A good place to begin is by focusing on a few simple habits:"),
            .subheading("Eat regularly"),
            .paragraph("Going long periods without eating can leave you tired, overly hungry, and more likely to grab whatever feels quickest later on."),
            .subheading("Build balanced meals"),
            .paragraph("Try to include a source of protein, some fibre, some colour, and healthy fats where you can."),
            .subheading("Think about variety"),
            .paragraph("Different foods bring different nutrients, so variety across the week matters more than getting every meal “perfect.”"),
            .subheading("Keep it realistic"),
            .paragraph("Simple meals you can repeat are often more helpful than complicated plans you won’t stick to."),
            .subheading("Aim for progress, not perfection"),
            .paragraph("You do not need to overhaul everything at once. A few small changes done consistently can be a very good place to start."),
        ]),

        Page(number: 8, heading: "Foods to enjoy more often", blocks: [
            .paragraph("When you’re trying to build a supportive pre-conception routine, it can help to include more of the following foods across the week:"),
            .subheading("Colourful fruit and vegetables"),
            .paragraph("Think berries, leafy greens, tomatoes, peppers, carrots, broccoli, citrus fruit, and avocado."),
            .subheading("Protein foods"),
            .paragraph("Eggs, yoghurt, beans, lentils, tofu, fish, chicken, cottage cheese, and other simple protein options can help meals feel more balanced."),
            .subheading("Higher-fibre carbohydrates"),
            .paragraph("Oats, wholegrains, brown rice, quinoa, sweet potatoes, beans, and lentils can support steadier energy."),
            .subheading("Healthy fats"),
            .paragraph("Olive oil, nuts, seeds, avocado, and oily fish can all be part of a balanced routine."),
            .subheading("Simple gut-friendly foods"),
            .paragraph("Fibre-rich foods and foods like live yoghurt or kefir can be a helpful addition for some people as part of an overall balanced diet."),
            .paragraph("You do not need to eat all of these every day. The aim is simply to bring them in more often over time."),
        ]),

        Page(number: 9, heading: "Foods and habits to be mindful of", blocks: [
            .paragraph("A balanced approach also means being a little more aware of things that can crowd out nourishing choices."),
            .paragraph("Try to be mindful of:"),
            .bullets([
                "Frequent sugary snacks and drinks.",
                "Relying heavily on ultra-processed foods.",
                "Skipping meals and then overeating later.",
                "Too much caffeine.",
                "Regular alcohol.",
                "Eating in a rushed, distracted way all the time.",
            ]),
            .paragraph("This is not about cutting everything out."),
            .paragraph("It is about making supportive choices more often, and noticing the habits that make you feel your best."),
        ]),

        Page(number: 10, heading: "Your 7-day starter plan", blocks: [
            .paragraph("This week is not about following a perfect menu."),
            .paragraph("It is about building a few simple habits that can help you feel more prepared, more nourished, and more in control."),
            .paragraph("Each day focuses on one small area to work on. Take what feels helpful, move at your own pace, and remember that consistency matters more than perfection."),
        ]),

        Page(number: 11, heading: "Day 1: Start with regular meals", blocks: [
            .subheading("Today’s focus"),
            .paragraph("Try not to leave long gaps between meals."),
            .subheading("Why it matters"),
            .paragraph("When you skip meals or go too long without eating, energy can dip and it can become harder to make balanced choices later in the day. For many people, a more regular eating pattern feels steadier and easier to maintain."),
            .subheading("What this can look like"),
            .paragraph("This does not mean eating on a rigid schedule. It simply means aiming for a gentle rhythm across the day. For example:"),
            .bullets([
                "Breakfast in the morning.",
                "Lunch around the middle of the day.",
                "Dinner in the evening.",
                "A snack if needed between meals.",
            ]),
            .subheading("Easy ways to do it"),
            .bullets([
                "Eat something within a couple of hours after getting up.",
                "Avoid relying on coffee until lunch time.",
                "Keep a simple snack ready for busy days.",
                "Try not to skip lunch and then overeat later on.",
            ]),
            .subheading("Try this today"),
            .paragraph("Plan roughly when you will eat your three main meals today."),
            .subheading("Reflection"),
            .paragraph("Did eating more regularly help you feel calmer or more energised?"),
        ]),

        Page(number: 12, heading: "Day 2: Build meals around balance", blocks: [
            .subheading("Today’s focus"),
            .paragraph("Aim to make meals a little more balanced."),
            .subheading("Why it matters"),
            .paragraph("A balanced meal can help you feel fuller for longer and support steadier energy through the day. It can also be a simple way to improve the overall quality of what you eat without overthinking it."),
            .subheading("What this can look like"),
            .paragraph("Try building meals around:"),
            .bullets([
                "A protein food.",
                "A higher-fibre carbohydrate.",
                "Some colour from fruit or vegetables.",
                "A healthy fat.",
            ]),
            .subheading("Easy ways to do it"),
            .bullets([
                "Porridge with yoghurt, berries, and seeds.",
                "Eggs on wholegrain toast with avocado.",
                "Lentil soup with wholegrain bread.",
                "Salmon, rice, and vegetables.",
                "A jacket potato with beans and salad.",
            ]),
            .subheading("Try this today"),
            .paragraph("Choose one meal today and ask yourself: could I add protein, fibre, colour, or healthy fat here?"),
            .subheading("Reflection"),
            .paragraph("What meal felt easiest to improve?"),
        ]),

        Page(number: 13, heading: "Day 3: Add more colour", blocks: [
            .subheading("Today’s focus"),
            .paragraph("Include more fruit and vegetables across the day."),
            .subheading("Why it matters"),
            .paragraph("Fruit and vegetables help add fibre, vitamins, minerals, and variety. They are one of the simplest places to start when you want to make your overall eating pattern feel more supportive."),
            .subheading("What this can look like"),
            .paragraph("You do not need elaborate recipes. Often it is just about adding an extra portion here and there."),
            .subheading("Easy ways to do it"),
            .bullets([
                "Berries with breakfast.",
                "Salad in a sandwich or wrap.",
                "Chopped veg with lunch.",
                "Extra vegetables with dinner.",
                "Fruit as part of a snack.",
                "Frozen vegetables for convenience.",
            ]),
            .subheading("Try this today"),
            .paragraph("Add one extra fruit or vegetable portion to two meals."),
            .subheading("Reflection"),
            .paragraph("What meal felt easiest to add? Fruit, salad, cooked vegetables, or something else?"),
        ]),

        Page(number: 14, heading: "Day 4: Focus on protein", blocks: [
            .subheading("Today’s focus"),
            .paragraph("Include a source of protein at meals, and sometimes snacks too."),
            .subheading("Why it matters"),
            .paragraph("Protein can help meals feel more satisfying and can support a steadier eating pattern through the day. It is also a simple way to avoid meals that leave you hungry again too quickly."),
            .subheading("What this can look like"),
            .paragraph("Protein foods include:"),
            .bullets([
                "Eggs", "Yoghurt", "Beans", "Lentils", "Tofu", "Chicken",
                "Fish", "Cheese", "Cottage cheese", "Nuts", "Seeds",
            ]),
            .subheading("Easy ways to do it"),
            .bullets([
                "Add Greek yoghurt to breakfast.",
                "Choose eggs on toast instead of toast alone.",
                "Include beans or lentils in soups and salads.",
                "Build lunches around chicken, tuna, tofu, or chickpeas.",
                "Choose yoghurt, nuts, or boiled eggs as a snack.",
            ]),
            .subheading("Try this today"),
            .paragraph("Look at your breakfast and lunch and see where you could make protein a little more obvious."),
            .subheading("Reflection"),
            .paragraph("Which protein options feel easiest for your routine?"),
        ]),

        Page(number: 15, heading: "Day 5: Think about fibre and healthy fats", blocks: [
            .subheading("Today’s focus"),
            .paragraph("Bring in foods that help meals feel more nourishing and satisfying."),
            .subheading("Why it matters"),
            .paragraph("Fibre and healthy fats can help support a balanced way of eating and make meals feel more complete. They are also an easy way to move away from overly processed grab-and-go habits."),
            .subheading("What this can look like"),
            .paragraph("Foods to think about more often include:"),
            .bullets([
                "Oats", "Beans", "Lentils", "Wholegrains", "Vegetables",
                "Fruit", "Avocado", "Olive oil", "Nuts", "Seeds",
            ]),
            .subheading("Easy ways to do it"),
            .bullets([
                "Drizzle olive oil on salads or vegetables.",
                "Add seeds to yoghurt or porridge.",
                "Include avocado with lunch.",
                "Swap to wholegrain bread or oats.",
                "Add beans or lentils to meals you already make.",
            ]),
            .subheading("Try this today"),
            .paragraph("Choose one meal and one snack where you can add either fibre or healthy fats."),
            .subheading("Reflection"),
            .paragraph("What small swap felt most realistic?"),
        ]),

        Page(number: 16, heading: "Day 6: Support the basics", blocks: [
            .subheading("Today’s focus"),
            .paragraph("Pay attention to the basics that often get overlooked."),
            .subheading("Why it matters"),
            .paragraph("Food matters, but so do the habits around it. Hydration, sleep, stress, and a little movement can all help you feel more supported and more consistent."),
            .subheading("What this can look like"),
            .paragraph("Keep it simple:"),
            .bullets([
                "Drink water regularly.",
                "Go for a short walk.",
                "Eat sitting down where you can.",
                "Slow things down slightly.",
                "Aim for a better bedtime tonight.",
            ]),
            .subheading("Easy ways to do it"),
            .bullets([
                "Keep a water bottle nearby.",
                "Take a 10-minute walk after lunch.",
                "Put your phone down while eating one meal.",
                "Prep breakfast or lunch for tomorrow.",
                "Go to bed a little earlier than usual.",
            ]),
            .subheading("Try this today"),
            .paragraph("Pick one non-food habit to support yourself with."),
            .subheading("Reflection"),
            .paragraph("What basic habit makes the biggest difference to how you feel?"),
        ]),

        Page(number: 17, heading: "Day 7: Make it realistic", blocks: [
            .subheading("Today’s focus"),
            .paragraph("Work out what feels sustainable for you."),
            .subheading("Why it matters"),
            .paragraph("The best routine is not the most perfect one — it is the one you can keep going with. This week is about noticing what works in real life."),
            .subheading("What this can look like"),
            .bullets([
                "What felt easy.",
                "What felt difficult.",
                "What meals or habits you would repeat.",
                "What support would help next.",
            ]),
            .subheading("Easy ways to do it"),
            .paragraph("Write down:"),
            .bullets([
                "3 breakfasts you would happily repeat.",
                "3 lunches or dinners that feel easy.",
                "3 snacks that work for busy days.",
                "2 habits you want to continue next week.",
            ]),
            .subheading("Try this today"),
            .paragraph("Create your own “keep it going” list for next week."),
            .subheading("Reflection"),
            .paragraph("What are the two or three changes you genuinely want to keep?"),
        ]),

        Page(number: 18, heading: "A simple starter shopping list", blocks: [
            .paragraph("You do not need a long or expensive list to get started."),
            .paragraph("A few useful staples might include:"),
            .subheading("Fruit and vegetables"),
            .bullets([
                "Berries", "Bananas", "Apples", "Leafy greens", "Tomatoes",
                "Cucumbers", "Peppers", "Carrots", "Broccoli",
                "Sweet potatoes", "Avocados",
            ]),
            .subheading("Protein foods"),
            .bullets([
                "Eggs", "Greek yoghurt", "Cottage cheese", "Chicken", "Fish",
                "Tofu", "Beans", "Lentils", "Chickpeas",
            ]),
            .subheading("Carbohydrates and fibre-rich foods"),
            .bullets([
                "Oats", "Brown rice", "Quinoa", "Wholegrain bread",
                "Potatoes", "Wraps", "Lentils", "Beans",
            ]),
            .subheading("Healthy fats and extras"),
            .bullets(["Olive oil", "Nuts", "Seeds", "Hummus", "Nut butter"]),
            .paragraph("Choose what suits your taste, budget, and routine."),
        ]),

        Page(number: 19, heading: "A gentle note for partners", blocks: [
            .paragraph("Preparing for pregnancy can be a shared journey."),
            .paragraph("While this guide is focused mainly on general nutrition habits before pregnancy, it is worth remembering that overall health matters for partners too."),
            .paragraph("Simple habits such as:"),
            .bullets([
                "Eating well.",
                "Sleeping enough.",
                "Staying active.",
                "Reducing smoking.",
                "Cutting back on excess alcohol.",
                "Managing stress where possible.",
            ]),
            .paragraph("Can all be supportive steps as part of a wider healthy lifestyle."),
            .paragraph("You do not need to do everything at once. Small changes count here too."),
        ]),

        Page(number: 20, heading: "You’ve made a start", blocks: [
            .paragraph("And that matters more than you think."),
            .paragraph("Trying to conceive can bring a mix of hope, excitement, questions, and uncertainty. But building a few supportive habits can help you feel more grounded and more in control."),
            .paragraph("Thank you for reading this guide."),
            .paragraph("We hope it has given you a calm and practical place to begin."),
            // Departure 3. The printed page ends with a mistyped invitation to download the app,
            // beside a QR code to the website. Read inside the app, both are dead ends.
            .paragraph("Everything here carries on inside Genesyx. Track how you feel, log what you eat and drink, and read a little more each week."),
        ]),
    ]
}
