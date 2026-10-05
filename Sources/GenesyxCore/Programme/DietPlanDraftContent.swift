import Foundation

/// DRAFT CONTENT: pending medical and editorial review.
///
/// The words of Your Diet Plan: a food guide entry for each of the six food groups, the categories
/// of the eight existing recipes, and a body for each of the thirteen weekly nutrition focuses.
/// Every item is marked `draft` and flagged for a clinical reader.
///
/// What this copy may say: what belongs in a group, everyday examples, variety, routine and
/// practical ideas. What it never says: what a food or a nutrient does for a body, how much of
/// anything to eat, or how many groups a day ought to hold. It names no supplement and gives no
/// medical guidance beyond the one allergy sentence.
///
/// Every string below reaches `DietPlanContent.allSurfaces`, which the guard tests scan.
extension DietPlanContent {

    public static let draft = DietPlanContent(
        foodGuide: draftFoodGuide,
        allergyNote: "If you have an allergy, a medical condition or dietary needs, follow the advice of "
            + "your GP or a registered dietitian.",
        mealCards: mealCards(for: RecipeContent.all, categories: draftMealCategories),
        weekTexts: draftWeekTexts
    )

    // MARK: - Food guide

    /// Group membership follows the tracker's own definitions (`FoodGroup.examples`): beans and
    /// pulses sit under protein, and nuts, seeds and avocado sit under oils and fats.
    private static let draftFoodGuide: [DietPlanFoodGuideEntry] = [
        DietPlanFoodGuideEntry(
            .vegetables,
            learn: "This group covers every kind of vegetable: fresh, frozen or tinned, raw or cooked, on its "
                + "own or as part of a dish. Salad, greens, peppers and carrots all sit here, and so do the "
                + "onions and tomatoes cooked into a sauce, soup, stew or curry. In the food group tracker, "
                + "tick Vegetables on any day a meal or snack included some. One tick records the day, "
                + "however much or little there was.",
            examples: ["Carrots", "Broccoli", "Spinach", "Peppers", "Tomatoes", "Onions", "Frozen peas",
                       "Cabbage or spring greens", "Okra", "Aubergine", "Pak choi", "Courgette"],
            tryIt: "Add a handful of frozen peas or spinach to a pasta sauce, curry or soup for the last few "
                + "minutes of cooking."
        ),
        DietPlanFoodGuideEntry(
            .fruit,
            learn: "This group is fruit in all its forms: fresh, frozen, tinned and dried. Berries, apples, "
                + "bananas and citrus fruit belong here, along with the fruit you might add to cereal, "
                + "yoghurt or a packed lunch. It sits apart from vegetables in the food group tracker so "
                + "that each can be recorded on its own. Tick Fruit on any day you had some, whether it was "
                + "a whole piece or part of a meal.",
            examples: ["Apples", "Bananas", "Oranges or satsumas", "Fresh or frozen berries", "Grapes", "Pears",
                       "Mango", "Melon", "Pineapple", "Tinned peaches", "Raisins or dates", "Kiwi fruit"],
            tryIt: "Keep fruit where you can see it, such as a bowl on the table, or add sliced banana or "
                + "frozen berries to breakfast."
        ),
        DietPlanFoodGuideEntry(
            .starchyCarbs,
            learn: "Starchy carbs are the foods many meals are built around: potatoes, bread, rice, pasta and "
                + "oats. Chapati, noodles, couscous, yam, plantain and breakfast cereals belong here too, in "
                + "white, brown and wholemeal versions alike. Most households have a few favourites that "
                + "come round week after week. In the food group tracker, tick Starchy carbs on any day one "
                + "of these foods was on your plate.",
            examples: ["Potatoes", "Wholemeal or white bread", "Rice", "Pasta", "Porridge oats",
                       "Chapati or roti", "Noodles", "Couscous", "Yam", "Plantain", "Breakfast cereal", "Quinoa"],
            tryIt: "Swap the base of a familiar meal for a different one from this group, such as couscous or "
                + "noodles in place of rice."
        ),
        DietPlanFoodGuideEntry(
            .protein,
            learn: "This group brings together beans, pulses, fish, eggs, meat and tofu. It is a wide group "
                + "with plenty of plant-based choices, such as lentils, chickpeas, baked beans and soya "
                + "mince, alongside eggs, fish and meat for those who eat them. Tins, jars and the freezer "
                + "count just as much as fresh. Tick Protein in the food group tracker on any day a meal "
                + "included one of these foods.",
            examples: ["Lentils", "Chickpeas", "Baked beans", "Kidney beans or black beans", "Tofu",
                       "Soya mince or tempeh", "Eggs", "Cod or other white fish", "Salmon", "Chicken",
                       "Beef or lamb"],
            tryIt: "Stir a tin of chickpeas or lentils into a soup, curry or pasta sauce you already make."
        ),
        DietPlanFoodGuideEntry(
            .dairy,
            learn: "This group is milk, yoghurt and cheese, together with the plant-based alternatives to "
                + "them, such as soya, oat and almond drinks and yoghurts, including fortified ones. It "
                + "covers the milk in your tea or on your cereal as well as the cheese in a sandwich or the "
                + "yoghurt after a meal. Tick Dairy & alternatives in the food group tracker on any day you "
                + "had something from either side of the group.",
            examples: ["Milk", "Yoghurt", "Kefir", "Cheddar or other hard cheese", "Cottage cheese", "Paneer",
                       "Lassi", "Fortified soya drink", "Fortified oat or almond drink",
                       "Plant-based yoghurt alternative"],
            tryIt: "Add a spoonful of yoghurt, or a plant-based alternative, to porridge, fruit or a bowl of dal."
        ),
        DietPlanFoodGuideEntry(
            .oilsAndFats,
            learn: "In the food group tracker this group holds cooking oils and spreads, together with nuts, "
                + "seeds and avocado. Olive, rapeseed and sunflower oil all sit here, as do peanut butter, "
                + "tahini and the seeds scattered over a salad or stirred into porridge. A meal often "
                + "includes this group through the way it was cooked or dressed. Tick Oils & fats on any day "
                + "one of these foods was part of what you ate.",
            examples: ["Olive oil", "Rapeseed oil", "Sunflower oil", "Vegetable oil spread", "Almonds or walnuts",
                       "Peanuts or peanut butter", "Pumpkin or sunflower seeds", "Ground flaxseed or chia seeds",
                       "Tahini", "Avocado"],
            tryIt: "Scatter a few seeds or chopped nuts over porridge, salad or soup, or mash avocado on toast."
        ),
    ]

    // MARK: - Meal inspiration

    /// The categories of each existing recipe, keyed by `Recipe.id`. The food groups are NOT listed
    /// here: each card reads them from the recipe's own `groups`.
    ///
    /// What the recipe data settles, and a test holds each one to it:
    ///   • quick: `Recipe.minutes` at or under `DietPlanMealCategory.quickMinutesLimit`.
    ///   • vegetarian: no meat or fish in `Recipe.ingredients`.
    ///   • plantBased: vegetarian, and no dairy, egg, honey or chocolate in `Recipe.ingredients`.
    ///   • breakfast: the recipe's own name says so.
    ///
    /// JUDGEMENT, for a reviewer: a recipe has no mealtime field, so lunch, dinner and snack below
    /// are read from the kind of dish and kept to one mealtime each. Soup, salad and a rice bowl
    /// are placed at lunch; a dal and the two traybakes at dinner; the oat bars as a snack. The
    /// twenty-minute limit for quick is a judgement too.
    static let draftMealCategories: [String: [DietPlanMealCategory]] = [
        "Lentil, spinach and lemon dal": [.dinner, .vegetarian, .plantBased],
        "Ginger and sweet potato soup": [.lunch, .vegetarian, .plantBased],
        "Kefir and berry breakfast bowl": [.breakfast, .quick, .vegetarian],
        "Sprouted seed and tofu traybake": [.dinner, .vegetarian, .plantBased],
        "Big green salad with quinoa": [.lunch, .vegetarian, .plantBased],
        "Rainbow pepper and bean bowl": [.lunch, .quick, .vegetarian, .plantBased],
        "Dark chocolate and almond oat bars": [.snack, .vegetarian],
        "Salmon, oats and greens traybake": [.dinner],
    ]

    // MARK: - Weekly nutrition text

    /// One body for each programme week, written for the focus titles in `ProgrammeContent.draft`.
    /// A test pins the titles these were written for, so a retitled focus cannot keep an old body.
    private static let draftWeekTexts: [DietPlanWeekText] = [
        DietPlanWeekText(
            1,
            body: "This week is about seeing what your eating routine looks like right now. Nothing needs to "
                + "change. Each day, open the food group tracker and tick the groups that were part of your "
                + "meals and snacks. Some days will have more ticks than others, and that is simply what the "
                + "record shows. By the end of the week you may have a first picture of your usual routine "
                + "to look back on.",
            tryThisWeek: "This week, try filling in the food group tracker at the same moment each day, such "
                + "as after your evening meal."
        ),
        DietPlanWeekText(
            2,
            body: "Once you have a few days recorded, look at which food groups appear and when. You may "
                + "see the same breakfast most mornings, or one group that tends to arrive with a particular "
                + "meal. This is noticing, not judging: a routine built around a few familiar meals is a "
                + "perfectly ordinary one. Variety can be as small as a different vegetable in a dish you "
                + "already cook, or a different fruit in the shopping basket.",
            tryThisWeek: "This week, try swapping one ingredient in a meal you make often for another from "
                + "the same food group."
        ),
        DietPlanWeekText(
            3,
            body: "A balanced plate is a simple picture for putting a meal together: some vegetables or "
                + "fruit, a starchy carb and a protein food, often with some dairy or an alternative and an "
                + "oil or fat used in the cooking. Not every meal looks like this, and it does not need to. "
                + "Over a day or a week, the six food groups in the tracker tend to turn up across different "
                + "meals, and your record lets you see how.",
            tryThisWeek: "This week, try naming the food groups on your plate at one meal a day before you "
                + "tick them."
        ),
        DietPlanWeekText(
            4,
            body: "This week the focus moves to what you drink with your meals. Water has its own tracker in "
                + "the app, separate from the food group tracker, and the two are easy to fill in together. "
                + "A glass on the table at mealtimes, or a bottle that travels with you, makes water part "
                + "of a routine you already have. Log each glass as you go so that the record keeps up with "
                + "your day.",
            tryThisWeek: "This week, try pouring a glass of water each time you sit down to eat, and log it then."
        ),
        DietPlanWeekText(
            5,
            body: "Fruit and vegetables are two separate groups in the food group tracker, and this week is "
                + "about the range within each. Fresh, frozen, tinned and dried all count, and so do the "
                + "vegetables cooked into a curry, stew, soup or sauce. Markets, corner shops and the "
                + "freezer aisle are all useful places to find something different. A new choice can sit "
                + "beside your usual favourites, and nothing has to be given up to make room.",
            tryThisWeek: "This week, try one fruit or vegetable you do not usually buy, in a dish you already "
                + "know how to make."
        ),
        DietPlanWeekText(
            6,
            body: "The protein group is a wide one: beans, pulses, fish, eggs, meat and tofu all belong to "
                + "it. This week, notice which of these you tend to return to, and where another could fit "
                + "just as easily. A tin of chickpeas or lentils works in most soups, curries and salads, "
                + "and eggs or tofu cook in minutes. Whether you eat meat, fish, both or neither, there is "
                + "plenty of room to move around inside this group.",
            tryThisWeek: "This week, try one meal built around beans, lentils or tofu, using a recipe from "
                + "Your Diet Plan if you would like a starting point."
        ),
        DietPlanWeekText(
            7,
            body: "Fibre comes from plant foods. It is found in vegetables, fruit, beans and pulses, and in "
                + "starchy carbs such as oats, potatoes eaten with their skins, and wholemeal or brown "
                + "versions of bread, rice and pasta. This week, simply notice where these foods already "
                + "appear in your meals. The food group tracker does not record fibre itself, so the "
                + "Vegetables, Fruit and Starchy carbs ticks are the closest record you have.",
            tryThisWeek: "This week, try a wholemeal or brown version of a bread, rice or pasta you already "
                + "eat, and see how you find it."
        ),
        DietPlanWeekText(
            8,
            body: "Oils and fats are often the quietest part of a meal: the oil a dish was cooked in, the "
                + "dressing on a salad, the spread on toast. In the food group tracker the group also holds "
                + "nuts, seeds and avocado. This week, notice where they show up in what you already eat. "
                + "They are easy to overlook when you tick your groups, because they are so often part of "
                + "the cooking and not the main event.",
            tryThisWeek: "This week, try adding a spoonful of seeds or chopped nuts to a breakfast, salad or "
                + "soup, and tick Oils & fats when you do."
        ),
        DietPlanWeekText(
            9,
            body: "This week looks at when you eat, not what. Some people eat at set times and others fit "
                + "meals around work, family or shifts, and both are routines. Notice the usual shape of "
                + "your day: when the first meal happens, whether meals come at similar times, and which "
                + "days run differently. The food group tracker records the day as a whole, so this is "
                + "something to observe for yourself. There is no timetable to keep to here.",
            tryThisWeek: "This week, try writing down roughly when you ate on two or three days, using the "
                + "notes in your Daily Log."
        ),
        DietPlanWeekText(
            10,
            body: "A little planning can make everyday meals simpler. That might mean choosing two or three "
                + "dinners before you shop, cooking a larger batch of soup or dal for another day, or "
                + "keeping tins of beans, frozen vegetables and eggs in the house for the evenings when "
                + "plans change. Preparation does not have to be elaborate. The aim is only to have "
                + "something you like within reach, and to keep logging easy.",
            tryThisWeek: "This week, try choosing two meals in advance and adding their ingredients to your "
                + "shopping list."
        ),
        DietPlanWeekText(
            11,
            body: "The habits that last are usually the ones that fit your life as it is: your budget, your "
                + "time, your tastes, your culture and the people you eat with. This week, think about which "
                + "of the things you have tried so far felt easy to keep going, and which felt like hard "
                + "work. It is fine to let the second kind go. A routine you can keep without much effort is "
                + "the one worth holding on to.",
            tryThisWeek: "This week, try naming one food habit from the programme so far that you would be "
                + "happy to keep."
        ),
        DietPlanWeekText(
            12,
            body: "By now the food group tracker may hold several weeks of entries, and Your Diet Plan "
                + "shows them as plain facts: the number of days with a nutrition check-in, and the number "
                + "of days each food group was recorded. Read these as a description of what you logged and "
                + "nothing more. They are not marks, and there is no figure to reach. The counts describe "
                + "your routine and how often you logged it.",
            tryThisWeek: "This week, try looking back over your recent weeks in Your Diet Plan and noticing "
                + "one thing about your routine that you had not seen before."
        ),
        DietPlanWeekText(
            13,
            body: "The programme is drawing to a close, and your food routine carries on beyond it. This "
                + "week, decide what you would like to keep: perhaps a regular time to log, a few meals you "
                + "now cook often, or the habit of noticing variety from one week to the next. Choose what "
                + "suits you and your household. Your record remains a record, and nothing in it is a target.",
            tryThisWeek: "This week, try writing down two or three food habits you want to carry on with, and "
                + "keep the note somewhere you will see it."
        ),
    ]
}
