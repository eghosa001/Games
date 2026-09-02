using System;
using UnityEngine;
using Renew.Core;

namespace Renew.Restoration
{
    [Serializable]
    public class RestorationCosts
    {
        public float cleaning = 500f;
        public float repair = 1500f;
        public float rebuild = 4000f;
        public float installation = 2500f;
        public float design = 1000f;
    }

    public class RestorableProperty : MonoBehaviour
    {
        [SerializeField] private string propertyId;
        [SerializeField] private string propertyName = "Abandoned Property";
        [SerializeField] private PropertyType propertyType = PropertyType.Warehouse;
        [SerializeField] private RestorationStage stage = RestorationStage.Neglected;
        [SerializeField] private float condition = 0f;
        [SerializeField] private RestorationCosts costs = new RestorationCosts();

        public string PropertyId => propertyId;
        public string PropertyName => propertyName;
        public PropertyType Type => propertyType;
        public RestorationStage Stage => stage;
        public float Condition => condition;
        public bool IsOperational => stage == RestorationStage.Operational;

        public event Action<RestorationStage> StageChanged;

        public bool RestoreNextStep(float availableCash, out float cost)
        {
            cost = GetNextCost();
            if (cost < 0f || availableCash < cost) return false;

            switch (stage)
            {
                case RestorationStage.Neglected: stage = RestorationStage.Cleaned; break;
                case RestorationStage.Cleaned: stage = RestorationStage.Repaired; break;
                case RestorationStage.Repaired: stage = RestorationStage.Rebuilt; break;
                case RestorationStage.Rebuilt: stage = RestorationStage.Installed; break;
                case RestorationStage.Installed: stage = RestorationStage.Designed; break;
                case RestorationStage.Designed: stage = RestorationStage.Operational; break;
                default: return false;
            }

            condition = Mathf.Clamp01((int)stage / 6f);
            StageChanged?.Invoke(stage);
            return true;
        }

        public float GetNextCost()
        {
            switch (stage)
            {
                case RestorationStage.Neglected: return costs.cleaning;
                case RestorationStage.Cleaned: return costs.repair;
                case RestorationStage.Repaired: return costs.rebuild;
                case RestorationStage.Rebuilt: return costs.installation;
                case RestorationStage.Installed: return costs.design;
                case RestorationStage.Designed: return 0f;
                default: return -1f;
            }
        }
    }
}
