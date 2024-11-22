import { Controller } from "@hotwired/stimulus"
import { rowFieldToggle } from "mixins/row_field_toggle";

export default class extends rowFieldToggle(Controller) {

  static targets = ["usersCommand", "userForm", "userFormUserID", "userFormCommand" ,
                    "problemsCommand", "problemForm", "problemFormProblemID", "problemFormCommand" ,
                    "toggleForm",
                   ]

  connect() {
  }

  setActiveTopic(event) {
    const badge = event.target

    const targetElement = event.currentTarget;

    // Iterate over all .topic-badge elements
    this.element.querySelectorAll(".topic-badge").forEach((badge) => {
      if (badge === targetElement) {
        badge.classList.add("text-bg-secondary");
        badge.classList.remove("text-bg-light", "border", "border-");
      } else {
        badge.classList.remove("text-bg-secondary");
        badge.classList.add("y1", "y2");
      }
    });

  }


}
